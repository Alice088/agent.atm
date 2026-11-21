# Runtime Trace — нормативная спецификация v2

Заменяет `agent.atm.txt` в части семантики. `agent.atm.txt` остаётся исходным документом v1 и
источником требований. Статья — `tracing_the_messy_middle_research.pdf`.

Проверяемые артефакты: `specs/schema.sql` (DDL), `specs/schema_smoke.sql` (данные + запросы
ко всем представлениям).

---

## 1. Принципы

Пять инвариантов. Нарушение любого — дефект, а не компромисс.

1. **Не выводить один факт из другого молча.** Каждое поле, полученное из наблюдения, несёт
   источник и уверенность. Отсутствие данных — `null` с причиной, а не подстановка соседнего поля.
2. **Две правды о маршрутизации.** `requested_model` и `resolved_model` описывают разные системы
   (политика и провайдер). Расхождение хранится, а не разрешается.
3. **Запись начинается в момент запроса.** Провал запроса — это запись, а не отсутствие записи.
4. **Задача — атрибут, а не период.** Любое событие может быть отнесено к задаче задним числом.
5. **Ни одна метрика не определяется в интерфейсе.** Метрика существует, если она описана в
   `metric_definitions` и реализована представлением или запросом.

---

## 2. Гранулярность

| Сущность | Идентификатор | Что это | Где живёт |
|---|---|---|---|
| Runtime transaction | `transaction_id` | один вызов LLM: старт запроса → ответ или провал | `runtime_transactions` |
| Turn | `turn_id` | ход: ввод пользователя и всё, что до следующего ввода | `turns` |
| Action | `action_id` | действие внутри сессии: инструмент, компактизация, смена модели | `actions` |
| Session | `session_id` | непрерывная работа агента, один процесс | `sessions` |
| Adapter instance | `instance_id` | один живой процесс адаптера: pid, хост, cwd, сессия | `adapter_instances` |
| Run | `run_id` | запуск агента от старта до `agent_settled` | `runs` |
| Branch | `branch_id` | ветка сессии после rewind/fork | `session_branches` |
| Task | `task_id` | намерение разработчика | `tasks` |
| Artifact | `artifact_id` | коммит, PR, файлы, CI-прогон | `artifacts` |

Связи кратности:

- задача → много сессий (интервалы в `task_sessions`), сессия → одна активная задача
  (частичный уникальный индекс `task_sessions_active_per_session`);
- сессия → много веток, ветка → свои turns и transactions;
- сессия → много запусков (`runs`), запуск → свои транзакции; сессия → много процессов адаптера.
- turn → много transactions, transaction → много actions;
- задача → много artifacts (`task_artifacts`), задача → одна текущая оценка (`task_outcomes`).

Ограничение v1 «одна сессия = одна задача» снято: оно делало `multi_session` недостижимым и
не давало отличить брошенную задачу от задачи, продолженной в новой сессии.

---

## 3. Схема транзакции

### 3.1. Совместимость с Table 1

19 полей статьи — **экспортируемая проекция**, а не предел хранения. Проекция реализована
представлением `transactions_19`, внутренняя таблица — суперсет. Правило: любое новое поле
обязано иметь правило проекции (в проекцию, в связанную сущность или в явный `НЕ ПРОЕЦИРУЕТСЯ`).

Соответствие строка-в-строку: 19 строк Table 1 дают 20 колонок проекции. Причина: `in/out_tokens`
разворачивается в две колонки, потому что вход и выход несравнимы между политиками; `stage/action_type`
остаётся одной строкой `stage || '/' || action_type`. Разворот обеих составных строк дал бы 21
колонку и нарушил бы соответствие Table 1 один-к-одному; свёртывание обеих дало бы 19 колонок и
сломало бы арифметику токенов.

Значения проекции:

| Поле Table 1 | Источник в v2 |
|---|---|
| `session_id` | `runtime_transactions.session_id` |
| `developer_id` | `runtime_transactions.developer_id` |
| `agent_tool` | `runtime_transactions.agent_tool` |
| `task_id` | `runtime_transactions.task_id` |
| `task_type` | `tasks.task_type` |
| `project` | `tasks.project_id` |
| `auth_mode` | `runtime_transactions.auth_mode` |
| `policy_id` | `runtime_transactions.policy_id` |
| `requested_model` | `runtime_transactions.requested_model` |
| `resolved_model` | `runtime_transactions.resolved_model` |
| `fallback_chain` | `runtime_transactions.observed_fallback_chain` |
| `request_ts` | `runtime_transactions.request_ts` |
| `in/out_tokens` | `input_tokens` / `output_tokens` |
| `status` | `runtime_transactions.status` |
| `retry_index` | `attempt_ordinal - 1` |
| `stage/action_type` | `stage || '/' || action_type` |
| `cost_usd` | `runtime_transactions.cost_usd` |
| `outcome_link` | `task_artifact_summary.primary_ref` — ссылка на основной артефакт |
| `outcome_type` | `task_outcome_resolved.artifact_class` |

`outcome_link` в проекции — **одно** значение, потому что поле Table 1 имеет тип `artifact ref`.
Множественность не теряется: все связи живут в `task_artifacts`, полный набор ссылок — в
`transactions_outcome_links.outcome_links` (массив), сводка — в `task_artifact_summary`.
Если задача имеет несколько артефактов, в проекцию попадает лучший подтверждённый:
порядок — ранг класса, затем флаг `is_primary`, затем время привязки.

Колонки, которых нет в проекции, не теряются: они живут в `runtime_transactions` и связанных
таблицах и доступны в аналитических запросах, но не в экспорте v1-совместимого датасета.

### 3.2. Модель и подмена провайдера

Правила:

1. `requested_model` — физическая модель, отправленная провайдеру (`message.model` в записи ответа),
   как в v1 §5 п.4. Это факт со стороны запроса, а не из `responseModel`.
2. `virtual_model` — псевдоним, выбранный пользователем или политикой (`sonnet-primary`), как v1
   предписывал хранить отдельно. Пустой, если псевдонима нет.
3. `resolved_model` — модель, которая фактически ответила. Заполняется из `resolved_model_gateway`,
   при его отсутствии — из `resolved_model_transcript`, с записью в `resolved_model_source`
   (`gateway` | `transcript` | `none`).
4. `model_divergence = true`, когда оба наблюдения `resolved_model_transcript` и
   `resolved_model_gateway` есть и различаются. Расхождение `virtual_model` ≠ `requested_model` —
   это маппинг псевдонима, а не подмена провайдера, и флагом не считается.
5. **Запрещено** правило v1 `resolved_model = responseModel ?? message.model`. При отсутствии
   ответа провайдера `resolved_model` равен `null`, `resolved_model_source = 'none'`. Подстановка
   `requested_model` в `resolved_model` превращает «нет данных» в утверждение «подмены не было» и
   стирает ровно тот эффект, ради которого строится Routing-слой.
6. `fallback_chain` в проекции — `observed_fallback_chain`: только реально наблюдаемые переключения,
   как требует v1 §5 п.5. Пустой массив, если переключений не было. Настроенная цепочка и её префикс
   на шаге доступны в `policy_fallback_context` и служат знаменателем для `fallback_rate`: без него
   частота fallback не определена.

### 3.3. Авторизация и биллинг — две оси

`auth_mode ∈ {api_key, oauth, unknown}` — тип учётных данных; домен совпадает с v1 без расширений.
`billing_mode ∈ {metered, subscription, free, unknown}` — режим оплаты.
`provider_kind ∈ {hosted, local, unknown}` — где исполняется модель: локальная модель — это
`provider_kind = 'local'`, а не отдельное значение `auth_mode`.

`billing_mode` не выводится из `auth_mode`. OAuth не означает подписку, подписка не означает OAuth.
Оба поля обязательны, `unknown` допустим для обоих; если адаптер не может определить режим оплаты,
он обязан записать `unknown`, а не угадывать `metered`.

Следствие для стоимости: `cost_usd` сравним только внутри `billing_mode = 'metered'`.
Для подписки он номинальный и агрегируется отдельно (`task_metrics.cost_usd_notional`,
`policy_comparison.notional_cost_per_completed_task`). Метрика, которая смешивает обе оси,
запрещена.

`auth_source` (`stored`, `environment`, `runtime`, `fallback`, `models_json_key`,
`models_json_command`, `unknown`) — метаинформация сбора, не поле схемы.

### 3.4. Стоимость

`cost_source ∈ {provider_reported, computed, none}`; `currency`; `price_table_version`.

- `provider_reported` — провайдер вернул стоимость сам; приоритет.
- `computed` — рассчитано по таблице цен; обязателен `price_table_version`.
- `none` — стоимости нет (подписка без номинала, локальная модель).

`task_metrics` разделяет `cost_usd_metered` и `cost_usd_notional`; сумма без фильтра по
`billing_mode` не является метрикой.

### 3.5. Токены

Хранится разложено: `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`,
`reasoning_tokens`. Правила:

- `input_tokens` — сумма по запросу, без вычитания кеша; кеш отдельно, чтобы не терять базу
  сравнения между политиками с разным кешированием;
- накопительные обновления одного сообщения не суммируются, берётся финальное значение;
- компактизация контекста не переписывает прошлые транзакции: она создаёт новую транзакцию и
  действие `context_compaction`;
- агрегат сессии — сумма по транзакциям head-ветки.

### 3.6. Время

`request_ts` — начало запроса, `response_ts` — конец, `duration_ms` — длительность.
Все три обязательны для завершённой транзакции; для `in_flight` обязателен только `request_ts`.

Хранение — `timestamptz` в UTC. Источник часов фиксируется в `raw_events.clock_source`.
Смещение часов между адаптером и приёмником оценивается в `clock_observations`. Время никогда не
является единственным ключом сопоставления.

### 3.7. Повторы и циклы починки

Три разных явления, которые v1 смешивал в одном `retry_index`:

| Явление | Поле | Источник |
|---|---|---|
| повтор HTTP-запроса провайдером | `provider_retry_count` | шлюз, если виден |
| авто-повтор агентом той же операции | `actions.action_type = 'transport_retry'` | `auto_retry_start` |
| цикл починки: новая попытка после неудачной проверки | `retry_family_id` + `attempt_ordinal` + `parent_transaction_id` | нормализатор |

Правила:

1. `attempt_ordinal` — номер попытки внутри `retry_family_id`, начиная с 1; `retry_index` в проекции
   равен `attempt_ordinal - 1`.
2. `retry_family_id` открывается, когда попытка следует за неуспешной проверкой (`stage = verify`
   с ошибкой) и несёт тот же `task_id`; закрывается при `stage = deliver` или завершении задачи.
3. `context_fingerprint` — хеш состава контекста попытки (набор файлов и их версии). Две попытки с
   одинаковым отпечатком — повтор без новой информации.
4. Транспортный повтор никогда не увеличивает `attempt_ordinal`: это тот же вызов, а не новая попытка.

Следствие: значение, которое v1 показывал как `retry_index`, в реальной сессии было почти всегда
нулём при десятках итераций починки — метрика измеряла не то явление.

---

## 4. Классификаторы

Все наборы значений хранятся в `classifier_versions` / `classifier_values` с версией
`taxonomy_version`. Значение вне набора отклоняется при нормализации, а не записывается как есть.

### 4.1. `stage` — стадия работы

`frame` → `locate` → `plan` → `edit` → `verify` → `repair` → `review` → `deliver`, плюс `unknown`.

Выводится конечным автоматом из потока действий turn'а, а не из имени события:

| Условие | Стадия |
|---|---|
| ввод пользователя, первое действие turn'а | `frame` |
| `semantic_action ∈ {read, search}` | `locate` |
| явное планирование или `semantic_action = delegate` до первой правки | `plan` |
| `semantic_action ∈ {edit, write}` | `edit` |
| `semantic_action ∈ {test, build}` | `verify` |
| `verify` завершилась ошибкой и далее идут правки | `repair` |
| `semantic_action = vcs` или запрос ревью | `review` |
| коммит, PR, финальный ответ без правок | `deliver` |

Стадия нужна отдельно от `action_type`, потому что петля 2 считает конверсию между стадиями, а не
частоту типов событий. В v1 стадии не было — воронка была невычислима.

### 4.2. `action_type` — событие

`user_input`, `llm_request`, `llm_response`, `tool_call`, `tool_result`, `tool_error`,
`context_compaction`, `branch_change`, `model_selection`, `transport_retry`, `turn_start`,
`turn_end`, `agent_completion`, `agent_abort`.

Покрытие подписок Pi (в v1 часть событий не имела отображения):

| Событие Pi | `action_type` |
|---|---|
| `message_start` (пользователь) | `user_input` |
| `message_start` (запрос модели) | `llm_request` |
| `message_end` | `llm_response` |
| `tool_execution_start` | `tool_call` |
| `tool_execution_end` | `tool_result` |
| `tool_execution_end` с `isError` | `tool_error` |
| `tool_execution_update` | не создаёт действия, обновляет существующее |
| `turn_start` | `turn_start` |
| `turn_end` | `turn_end` |
| `auto_retry_start` | `transport_retry` |
| `auto_retry_end` | закрывает `transport_retry` |
| события компактизации | `context_compaction` |
| события ветвления | `branch_change` |
| `model_select`, `model_change` | `model_selection` |
| `agent_settled` (успех) | `agent_completion` |
| `agent_settled` (прерывание) | `agent_abort` |

### 4.3. `semantic_action` — смысл инструмента

`read`, `search`, `edit`, `write`, `execute`, `test`, `build`, `vcs`, `network`, `delegate`, `other`.

Без этой оси пути вида «edit → пропуск теста → repair → abort» не распознаются: `tool_call` одинакова
для чтения файла и запуска тестов.

### 4.4. `status` — исход запроса

Поле `status` сохраняет домен v1 без расширений:
`success`, `error`, `timeout`, `cancelled`, `rate_limited`, `unknown`.

Детализация — в отдельном поле, чтобы исходная схема не менялась:
`status_detail ∈ {success, error_provider, error_client, timeout, cancelled, rate_limited,
malformed_tool_call, context_overflow, unknown}`.
Жизненный цикл — в третьем поле: `status_phase ∈ {in_flight, terminal}`.

Правила согласованности, проверяемые ограничениями БД:

1. `status_phase = 'in_flight'` ⇔ `status IS NULL AND response_ts IS NULL`.
2. `status_phase = 'terminal'` ⇒ `status IS NOT NULL`.
3. `status` — свёртка `status_detail`: `error_provider`, `error_client`, `malformed_tool_call`,
   `context_overflow` → `error`; остальные совпадают. Таблица свёртки — `classifier_mappings`.

Транзакция создаётся в `in_flight` при старте запроса и закрывается финальным статусом. Провал без
ответа модели — валидная транзакция с `status ≠ success`.

Статусы уровней «инструмент», «ход», «запуск» в `runtime_transactions.status` не смешиваются:
они принадлежат `actions.status`, `turns.outcome` и `runs.outcome` (граница запуска — `agent_settled`).

### 4.5. Результат задачи — две оси

`artifact_class ∈ {merged_pr, committed_patch, passing_unreviewed, partial_artifact, multi_session, none}`
`human_verdict ∈ {success, partial_success, failure, abandoned, unknown}`
`linkage_state ∈ {single_source, reconciled, ambiguous, pending, linked, timed_out, not_applicable}`

`artifact_class` — машинно устанавливаемый класс артефакта (набор статьи).
`human_verdict` — суждение человека.
`abandoned` как вердикт человека и `timed_out` как состояние линковки — разные вещи: первое не
доказывает отсутствие артефакта, второе фиксирует истечение окна.

Запрещено выводить `artifact_class` из `human_verdict` и наоборот.

---

## 5. Сбор

### 5.1. Конвейер

```
Adapter (hook | jsonl | api)
  → redaction (в адаптере, до буфера)
  → durable buffer (на диске)
  → POST /api/v1/events (идемпотентно по event_key)
  → raw_events (сырьё, JSONB, помечено версией процессора)
  → normalizer
  → turns / actions / runtime_transactions / artifacts
```

Тяжёлая работа в обработчике хука запрещена: хук только формирует событие и отдаёт в очередь.

### 5.2. Ключи дедупликации

Порядок применения, первый сработавший — канонический:

1. `event_key` — стабильный идентификатор источника, если он есть (`messageEntryId`,
   `toolResultEntryIds`, `toolCallId`).
2. `(agent_tool, session_id, entry_id)` — когда сессия разрешена.
3. `(agent_tool, cwd_hash, role, tool_call_id, event_ts)` — когда сессия не разрешена и
   идентификатора записи нет.

Ключ не должен зависеть от `session_id`, если `session_id` неизвестен; в v1 составной ключ включал
`session_id`, что замыкало разрешение сессии на дедупликацию, которая сама от него зависела.

### 5.3. Разрешение сессии

Порядок источников, каждый шаг фиксируется в `session_id_source` и `session_resolution_confidence`:

1. `hook_payload` — идентификатор в самом событии;
2. `adapter_context` — привязка процесса адаптера к сессии, установленная при старте;
3. `jsonl_header` — заголовок файла сессии;
4. `jsonl_mtime_match` — ближайший по времени файл в `cwd` (низкая уверенность);
5. `unresolved` — событие сохраняется с `session_id = null` и `session_resolution_state = 'pending'`,
   попадает в очередь `raw_events_unresolved` и разрешается позже всем каталогом сессий.

События с `pending` не отбрасываются и не приписываются произвольно. Два процесса Pi в одном `cwd`
различаются по `adapter_context`, а не по времени.

### 5.4. Ветки

Каждая производная запись получает `branch_id`. Rewind создаёт новую ветку с
`forked_at_entry_id`. Правила:

- агрегаты по умолчанию считаются по `is_head = true` и по ветке, существовавшей на момент
  закрытия задачи;
- расходящиеся ветки не суммируются с head: иначе повторное прохождение удваивает токены;
- `branch_change` — обязательное действие, без него ветка не создаётся.

### 5.5. Конфликт источников

При расхождении hook-события и записи JSONL действует приоритет:

1. факт существования запроса — по hook (реальное время);
2. финальные значения токенов, модели, стоимости — по JSONL (более полная запись);
3. стоимость от провайдера — по шлюзу (если есть).

Проигравшая версия не удаляется: строка помечается `superseded_by` и остаётся для аудита.
Молчаливая перезапись запрещена.

---

## 6. Сверка и линковка

### 6.1. Сверка gateway ↔ transcript

Пара сопоставляется, если совпали: окно времени (`reconciliation_window_seconds`, по умолчанию 120),
имя модели, входные и выходные токены. Результат — `linkage_state` и `match_confidence`.

Классы:

- `reconciled` — пара найдена, один к одному;
- `ambiguous` — кандидатов больше одного;
- `single_source` — второго источника нет по конструкции (подписочный режим, локальная модель).

`single_source` — легальное состояние, а не ошибка сопоставления. Именно это различие требует
статья: отсутствие записи шлюза несёт диагностический смысл и не должно выглядеть как провал join'а.

Отчёт о качестве: `capture_quality` (доля состояний по инструменту и источнику).

### 6.2. Линковка артефактов

Окно линковки — `linkage_window_hours` (по умолчанию 72) от закрытия задачи. Линковка возможна
и после закрытия: артефакт, появившийся позже, привязывается и пересчитывает `outcome`.

Правила по классам:

| Класс | Условие |
|---|---|
| `partial_artifact` | первый шаг: список файлов из Pi (`details.readFiles`, `details.modifiedFiles`, `bashExecutionMessage.fullOutputPath`) даёт артефакт `kind = 'file_set'` с `link_method = 'agent_file_evidence'` и низкой уверенностью |
| `committed_patch` | коммит в том же репозитории, ветка из сессии, пересечение файлов ≥ 1, время ≤ окна |
| `merged_pr` | PR, содержащий такой коммит, в состоянии merged |
| `passing_unreviewed` | тесты пройдены в CI, ревью нет |
| `multi_session` | артефакт достигнут при ≥ 2 сессиях одной задачи |
| `none` | артефакта нет и окно не истекло |

Порядок повышения класса повторяет v1 §5 п.8: сначала свидетельство файлов от агента, затем Git,
затем PR и CI. `file_set` не отменяет коммит и не заменяет его: артефакт с `observed_by =
'agent_tool'` имеет `is_primary = false` и перестаёт учитываться, когда появляется `commit` или `pr`.
Список файлов от агента неполон (изменения через Bash и внешние процессы в него не попадают), поэтому
его уверенность ниже и он не может единолично дать `committed_patch`.

`abandoned` не выставляется человеком по умолчанию: по истечении окна задача переходит в
`linkage_state = timed_out`, и только тогда `artifact_class = none` становится окончательным.
Кто и на основании чего решил — в `task_outcomes.decided_by` и `note`.

Наличие `outcome` к моменту закрытия задачи проверяется БД: отложенный constraint-триггер
`tasks_require_outcome` не даёт закрыть задачу без текущей строки `task_outcomes`. Это снимает
расхождение с `R∗` из Table 1: обязательность обеспечивается схемой, а не соглашением.

Порог уверенности и признаки матча сохраняются в `task_artifacts.match_features` и
`link_confidence`; версия алгоритма — `linker_version`.

### 6.3. Артефактов может быть несколько

Связь задача → артефакт — многие ко многим (`task_artifacts`), а не одно поле. Задача обрастает
артефактами во времени, и это нормальный режим, а не исключение:

| Момент | Что появляется |
|---|---|
| конец сессии | `file_set` — свидетельство файлов от агента |
| часы спустя | один или несколько `commit` в разных ветках |
| в течение окна | `ci_run` по любому из коммитов |
| дни спустя | `pr`, затем его merge |
| позже | правки: `commit` с fixup, дополнительный `pr` |

Правила:

1. Каждый артефакт имеет состояние `state ∈ {candidate, confirmed, superseded, rejected}`.
   `candidate` — след, требующий подтверждения; `confirmed` — учтён в классе; `superseded` —
   заменён более сильным (`superseded_by_artifact_id`); `rejected` — ложное срабатывание с причиной.
2. Класс задачи — максимум по рангу `artifact_class_rank` среди подтверждённых артефактов, а не
   выбранный вручную. Ранг: `merged_pr` 6, `committed_patch` 5, `multi_session` 4,
   `passing_unreviewed` 3, `partial_artifact` 2, `none` 0. Класс на каждый артефакт ставит линкер
   при привязке и хранит в `artifacts.artifact_class`.
3. Ручной класс в `task_outcomes.artifact_class` — это решение на момент закрытия. Если есть
   подтверждённые артефакты, аналитика берёт класс из них: `task_outcome_resolved.class_source`
   показывает `artifacts` или `decision`. Два источника не смешиваются: факт важнее суждения, но
   суждение сохраняется и видно в чьей строке оно стоит.
4. `is_primary` — только один артефакт на задачу (частичный уникальный индекс
   `task_artifacts_one_primary`). Флаг вторичен: он решает только ничьи внутри одного ранга.
5. Ссылки каноничны и строятся из полей артефакта (`artifact_refs`):
   `<repo>@<sha>` для коммита, `<repo>#pr-<n>` для PR, `ci:<run>` для прогона, `files:<n>` для набора
   файлов. Проекция и экспорт используют их, а не свободный URL.
6. `multi_session` не выставляется автоматически: `task_artifact_summary.crosses_sessions`
   сообщает, что артефакт достигнут через несколько сессий, и линкер выбирает этот класс сам,
   если более сильный класс не подтверждён.
7. `outcome_links` (массив в `transactions_outcome_links`) содержит только активные ссылки —
   `candidate` и `confirmed`. Вытесненные видны в `task_artifact_summary.all_artifact_refs`,
   чтобы история не терялась и список не раздувался устаревшими ссылками.
8. Линковка идёт после закрытия задачи и после каждой новой находки: артефакты добавляются,
   а не заменяют друг друга, поэтому повторный прогон линкера идемпотентен по
   `(task_id, artifact_id)` и не перезаписывает `linked_at`.

---

## 7. Петли обратной связи

Каждая метрика описана в `metric_definitions` и реализована представлением.

### 7.1. Петля 1 — coaching

Признаки, которых не было в v1:

| Признак | Определение | Реализация |
|---|---|---|
| контекст | число файлов и байт, попавших в контекст попытки | `context_breadth` |
| план | была ли стадия `plan` до первой правки | `turn_paths`, `stage_funnel` |
| ретраи без новой информации | доля попыток в `retry_family_id` с повторяющимся `context_fingerprint` | `futile_retries` |
| отказ | `linkage_state = timed_out` по типу задачи | `developer_cohorts` |

Когорта — (`developer_id`, `task_type`). Нижняя граница размера когорты — `settings.min_cohort_size`,
применяется в `developer_cohorts` через `HAVING`. Задачи без `task_type` в когорту не попадают:
их доля видна в `task_type_coverage` (`labeled_rate`), а не растворяется в `other`.

Сравнение с коллегами — `developer_peer_baseline`: для каждой когорты даёт среднюю долю завершённых
задач по всему типу задачи и отклонение от неё (`delta_vs_peers`, `repair_loop_delta_vs_peers`).
Без этого петля отвечает на вопрос «как у меня», но не на вопрос из Vignette 3 — «как у меня
по сравнению с теми, у кого тот же тип задачи получается».

Выдача петли — не отчёт, а `interventions` с гипотезой и параметрами.

### 7.2. Петля 2 — workflow

`stage_funnel` — абсолютные числа по стадиям, `stage_conversion` — доля задач, дошедших от стадии к
следующей, `turn_paths` — путь стадий на turn, `actions` с `semantic_action` — пропуск теста,
`futile_retries` — бесполезные циклы починки. Конверсия считается только по задачам, дошедшим до
исходной стадии: ноль у `repair → review` означает, что доставка после починки не состоялась.

Воронка считается по задачам, а не по сессиям: `stage_funnel` группирует по `task_id`.
Брошенность — `task_metrics.linkage_state` по стадии последнего действия.

### 7.3. Петля 3 — политика маршрутизации

`policy_comparison`: задачи, завершённые задачи, стоимость завершённой задачи (metered и notional
раздельно), циклы починки на задачу.
`fallback_rate_by_policy`: знаменатель — настроенная цепочка, числитель — `fallback_step > 1`.
`experiments` + `policy_assignments`: детерминированное бакетирование по `task_id` и соли,
без зависимости от шлюза.

Ключевое отличие от v1: `policy_id` — атрибут попытки, а не задачи. Смена модели внутри сессии
больше не делает атрибуцию задачи ложной.

### 7.4. Замыкание петли

`interventions` (что сделали) + `intervention_effects` (что изменилось: метрика, окна, объёмы,
метод, поправка на состав задач). Без этих таблиц петля заканчивается рекомендацией, которую
нельзя проверить, — это и есть разрыв, который статья называет intervention causality.

Уровень доказательности фиксируется явно в `causality_level`:

| `method` | `causality_level` | Что требуется |
|---|---|---|
| `before_after` | `association` | ничего, кроме окон |
| `ab_test` | `causal` | `experiments` + `policy_assignments` |
| `did` | `causal` | `control_value`, `control_n` — параллельная группа без вмешательства |
| `synthetic_control` | `causal` | `control_value` — синтетический контроль по прошлым периодам |

`before_after` не даёт права говорить «вмешательство сработало»: статья требует DiD или
синтетического контроля именно потому, что состав задач меняется. Эффект без контрольной группы
хранится как `association`, и интерфейс обязан показывать уровень, а не только число.

---

## 8. Версионирование

На каждой производной строке: `schema_version`, `normalizer_version`, `taxonomy_version`,
при необходимости `price_table_version`, `linker_version`. В `raw_events` — `processor_version`
и `processed_at`.

Повторная нормализация не перезаписывает историю: создаются новые строки, старые получают
`superseded_by`. Версия классификатора в строке позволяет сравнивать данные, полученные до и после
изменения правил, и не смешивать их в одном агрегате. Изменённая строка защищена триггером
`runtime_transactions_superseded_immutable`.

Изменение набора значений никогда не делается молча: `classifier_mappings` хранит соответствие
`(kind, from_version, from_value) → (to_version, to_value)`, включая свёртку `status_detail → status`
и переименование `retry → transport_retry`. Требование v1 «схема из 19 полей без изменений»
выполняется так: домены исходных полей сохранены, расширения живут в соседних полях, а любое
изменение значения имеет явную строку соответствия.

Адаптер и рантайм версионируются в `adapters` (`adapter_version`, `runtime_version`); имя рантайма
из конфигурации Pi сохраняется в `sessions.runtime_name`.

---

## 9. Адаптеры и внешние системы

### 9.1. Контракт адаптера

Адаптер объявляет:

- `adapter_id`, `agent_tool`, `adapter_version`, `runtime_version`;
- `capabilities` — по каждому полю схемы уровень: `full` | `partial` | `absent`;
- поток событий с `event_key` и `event_seq`;
- способ чтения истории (транскрипт), если он есть.

`absent` — нормальное объявление. Поле, отсутствующее у инструмента, записывается как `null` с
источником `none`, а не заполняется догадкой. Матрица покрытия доступна через `adapters.capabilities`
и воспроизводит таблицу ✓/△/× статьи машиночитаемо.

`agent_tool` — имя инструмента (`pi`, `claude_code`, `codex`, `cursor`, ...), а не имя пакета
рантайма. Требуется для кросс-инструментных когорт. Значение из конфигурации Pi (`piConfig.name`)
не теряется: оно хранится в `sessions.runtime_name` и остаётся доступным для отладки и сверки с
версией рантайма.

Обнаружение сессии без задачи и конкуренция нескольких процессов моделируются явно:
`adapter_instances` — регистрация живого процесса (`instance_id`, `pid`, `host`, `cwd_hash`,
`session_id`, `heartbeat_at`, `state`). Событие несёт `adapter_instance_id`, поэтому два процесса Pi
в одном `cwd` различимы, а шаг `adapter_context` в цепочке разрешения сессии (§5.3) имеет конкретный
источник, а не подразумеваемый.

### 9.2. Внешняя система

Внешняя система владеет: `developer_id`, `project_id`, `task_id`, `task_type`, `policy_id`,
`outcome`. Контракт — HTTP API, а не «внешняя система вообще»:

| Метод | Назначение |
|---|---|
| `POST /api/v1/tasks` | создать задачу |
| `PATCH /api/v1/tasks/{id}` | изменить атрибуты |
| `POST /api/v1/tasks/{id}/sessions` | привязать/отвязать сессию |
| `POST /api/v1/sessions` | зарегистрировать/обновить сессию (v1 §8) |
| `POST /api/v1/tasks/{id}/complete` | закрыть, выставить вердикт |
| `POST /api/v1/tasks/{id}/artifacts` | привязать артефакт вручную |
| `GET /api/v1/tasks/{id}` | состояние задачи, включая качество сбора |
| `GET /api/v1/sessions/{id}` | сессия, ветки, привязки (v1 §8) |
| `GET /api/v1/transactions` | постраничная выдача транзакций (v1 §8) |
| `GET /api/v1/metrics/{name}` | метрика с проверкой пола когорты |

Контракт v1 §8 сохранён полностью: `POST /api/v1/sessions`, `GET /api/v1/sessions/{id}` и
`GET /api/v1/transactions` остаются, а не заменяются вложенными путями. Вложенные `tasks/{id}/...`
добавлены, но не отменяют исходных.

Каждый вызов идемпотентен по своему ключу (`event_key`, `task_id`, `(task_id, artifact_id)`).

`policy_id` присваивается задаче внешней системой или экспериментом; адаптер его не изобретает.

### 9.3. OpenTelemetry

Транзакция → спан с атрибутами `gen_ai.request.model`, `gen_ai.response.model`,
`gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `gen_ai.provider.name`; действие → событие
спана. Экспорт OTLP выключен по умолчанию и допускается только в локальный коллектор после
редактирования.

Экспорт датасета — `transactions_19` в Parquet/CSV. Это и есть межпроектная единица обмена.

---

## 10. Приватность и управление

1. **Редактирование секретов — в адаптере, до буфера.** Второй проход на приёме. Отчёт о
   срабатываниях — `raw_events.redaction_report`; правила — `redaction_rules` с версией.
   Сохранение секрета в буфере или в `raw_events` — дефект.
2. **`developer_id` хранится только как хеш** с локальной солью (`salt_version`). Исходное значение
   не хранится ни локально, ни при экспорте. Режим задаётся `settings.developer_id_storage`:
   `hashed` (по умолчанию) | `plaintext_local`. Второй режим сохраняет возможность из v1 хранить
   идентификатор в исходном виде локально, но запрещает экспорт и отключает кросс-проектные когорты;
   выключен по умолчанию и включается только явно.
3. **Объём содержимого** задаётся `settings.capture_content`: `none` (только счётчики) |
   `metadata_only` (по умолчанию) | `full_local` (транскрипт целиком, только локально, экспорт
   запрещён). Это снимает противоречие v1 §3 и §10: хранение транскриптов разрешено явным режимом,
   а не подразумевается и не отрицается одновременно.
4. **Согласие**: `developer_consents` со `scope`, `granted_at`, `revoked_at`. Без действующего
   согласия события разработчика не собираются.
5. **Пол когорты**: `settings.min_cohort_size`; запросы, возвращающие агрегат меньше пола, обязаны
   отказать, а не округлить.
5. **Ретенция**: `retention_policies` для сырья, транзакций, действий, артефактов.
6. **Разделение контуров**: coaching-данные (разработчик видит свои) и management-агрегаты
   (только когорты) — разные метрики и разные эндпоинты.
7. **Запрет рейтинга**: метрики с `cohort_floor_applies = true` не выдаются по одному человеку;
   API не предоставляет сортировку разработчиков по производительности.
8. Текст сообщений и промптов не требуется ни одной метрике: по умолчанию хранятся `payload_bytes`,
   ссылки и агрегаты. Полный текст разрешён только явным режимом `capture_content = 'full_local'`
   из правила 3 и никогда не экспортируется.

Противоречие v1 («можно сохранять транскрипты» против «не собирать содержимое») снимается
настройкой `capture_content`, а не отрицанием одной из сторон.

---

## 11. Отказы

| Сценарий | Поведение |
|---|---|
| Приёмник недоступен | адаптер пишет в постоянный буфер, отправляет после восстановления |
| Приёмник упал между записью и подтверждением | повторная отправка, отсечение по `event_key` |
| Процесс Pi убит | незавершённые транзакции остаются `in_flight`; сверка с JSONL закрывает или помечает `unknown` |
| Задача закрыта, события идут | новые события не приписываются задаче; создаётся новая связь или новая задача |
| Артефакт появился после закрытия | линковка в пределах окна, `outcome` пересчитывается |
| Окно линковки истекло | `linkage_state = timed_out`, `artifact_class = none`, вердикт человека не подменяется |
| Не удалось свернуть сессию | `session_resolution_state = 'pending'`, событие не теряется |
| Смена классификатора | новая версия нормализатора, старые строки `superseded_by` |
| Часы расходятся | смещение в `clock_observations`, время не единственный ключ |

Статусы задачи: `pending`, `in_progress`, `awaiting_outcome`, `completed`, `abandoned`.
`awaiting_outcome` — задача закрыта человеком, окно линковки ещё открыто. `abandoned` — окно
истекло без артефакта. Статус и вердикт независимы: `completed` + `failure` — валидная комбинация.

Набор выбран потому, что v1 задавал его дважды и по-разному: `pending` только в пользовательском
сценарии, `in_progress/completed/abandoned` — в §12. Пять состояний покрывают оба набора;
`in_progress` отображается в интерфейсе как ACTIVE (`DESIGN.md` §6.1). Транзитная сверка при
завершении — не статус задачи, а состояние сбора, поэтому отдельного `finalizing` нет.

Уровень запуска живёт отдельно: `runs.outcome ∈ {settled, aborted, unknown}` с границей
`agent_settled`. `agent_end` границей не является и запуск не закрывает.

---

## 12. Матрица: дыра → решение

| # | Дыра v1 | Решение | Где |
|---|---|---|---|
| 1 | `resolved_model ?? message.model` фабрикует «подмены не было» | `null` + `resolved_model_source`, расхождение хранится | §3.2, `runtime_transactions`, `model_divergences` |
| 2 | `requested_model` из ответа ассистента | берётся со стороны запроса (`message.model`), псевдоним — в `virtual_model` | §3.2 |
| 3 | Нет второго источника правды (шлюза) | роли `source_primary` / `source_secondary`, `linkage_state` | §6.1, `capture_quality` |
| 4 | `retry_index` = транспортный авто-ретрей | три явления разделены: `provider_retry_count`, `transport_retry`, `retry_family_id` | §3.7 |
| 5 | Ретраи «без новой информации» не наблюдаемы | `context_fingerprint`, `futile_retries` | §7.1 |
| 6 | Нет `stage` → воронка невычислима | отдельная ось + автомат вывода | §4.1, `stage_funnel` |
| 7 | `fallback_chain` без знаменателя | `observed_fallback_chain` в проекции (v1), настроенная цепочка — в `policy_fallback_context` | §3.2, `fallback_rate_by_policy` |
| 8 | `auth_mode` смешивает креды и биллинг | две оси: `auth_mode` + `billing_mode` | §3.3 |
| 9 | `cost_usd` смешивает реальные и номинальные деньги | `cost_source`, `cost_usd_metered` / `cost_usd_notional` | §3.4, `task_metrics` |
| 10 | `outcome_type` — другая ось, потеряны 3 класса статьи | `artifact_class` × `human_verdict` | §4.5 |
| 11 | `abandoned` = выбор человека | `linkage_state = timed_out` по истечении окна | §6.2 |
| 12 | Артефакт после закрытия задачи теряется | линковка в окне после закрытия, пересчёт `outcome` | §6.2 |
| 13 | «Одна сессия = одна задача» | `task_sessions` с интервалами, задача → много сессий | §2 |
| 14 | Запрос без ответа не записывается | `in_flight` при старте запроса | §4.4 |
| 15 | Статусы 4 уровней негде хранить | `actions.status`, `turns.outcome`, `runs.outcome`, `sessions.status` | §4.4, §11 |
| 16 | Дедуп-ключ зависит от неизвестного `session_id` | иерархия ключей без `session_id` в последнем | §5.2 |
| 17 | Разрешение сессии не определено | цепочка источников + очередь `pending` | §5.3 |
| 18 | Нет приоритета hook/JSONL | правила по типу факта + `superseded_by` | §5.5 |
| 19 | Ветки ломают агрегаты | `branch_id` во всех записях, агрегат по head | §5.4 |
| 20 | Нет `duration`, «faster» не измеряется | `request_ts` / `response_ts` / `duration_ms` | §3.6 |
| 21 | Нет правил агрегации токенов | разложение на 5 токен-полей + правила | §3.5 |
| 22 | Версии объявлены, но негде хранить | версии на каждой производной строке | §8 |
| 23 | Нет контракта адаптера и матрицы покрытия | `capabilities` с `full/partial/absent` | §9.1 |
| 24 | `agent_tool` = имя пакета Pi | enum инструментов, кросс-инструментные когорты | §9.1 |
| 25 | Нет OTel и экспорта датасета | маппинг `gen_ai.*` + `transactions_19` | §9.3 |
| 26 | Место редакции секретов не задано | в адаптере до буфера + второй проход | §10.1 |
| 27 | `developer_id` в открытом виде локально | только хеш с солью | §10.2 |
| 28 | Управление из статьи отсутствует | согласие, пол когорты, ретенция, контуры, запрет рейтинга | §10 |
| 29 | Нет объекта вмешательства → петля не замыкается | `interventions` + `intervention_effects` | §7.4 |
| 30 | Нет A/B-инфраструктуры | `experiments` + детерминированное бакетирование | §7.3 |
| 31 | `policy_id` на задаче | `policy_id` на попытке + `policy_version` | §7.3 |
| 32 | Неполное покрытие событий → `action_type` | полная таблица соответствия | §4.2 |
| 33 | Нет семантики инструментов | `semantic_action` | §4.3 |
| 34 | Внешняя система без контракта | HTTP-контракт с идемпотентностью | §9.2 |
| 35 | Статусы задачи противоречивы | 5 статусов + машина переходов | §11 |
| 36 | «Широкий выбор контекста» не наблюдаем | `attempt_context` + `context_breadth` | §7.1 |
| 37 | Метрика стоимости на подписке даёт ноль | `metered` и `notional` в определении и представлении | §3.4, §7.3 |

Дыры, найденные проверкой плана против v1 и статьи:

| # | Дыра | Решение | Где |
|---|---|---|---|
| 38 | `requested_model` переопределён против v1 §5 п.4 | `requested_model` — физическая модель отправки, псевдоним — в `virtual_model` | §3.2 |
| 39 | `fallback_chain` подменён настроенной цепочкой | в проекции только наблюдаемые переключения; настроенная — в `policy_fallback_context` | §3.2 |
| 40 | `agent_tool` потерял значение из конфигурации Pi | `sessions.runtime_name` хранит `piConfig.name` | §9.1 |
| 41 | Домены исходных полей расширены молча | исходные домены сохранены; `status_detail`, `status_phase`, `provider_kind`, `billing_mode` — соседние поля; `classifier_mappings` | §4.4, §8 |
| 42 | `outcome` Required* не проверялся | constraint-триггер `tasks_require_outcome` | §6.2 |
| 43 | Запрет открытого `developer_id` против v1 §3 | режим `settings.developer_id_storage`, по умолчанию хеш | §10.2 |
| 44 | Запрет хранения текста против v1 §10 | режим `settings.capture_content`: `none` / `metadata_only` / `full_local` | §10.3 |
| 45 | Выпал первый шаг линковки — файлы из Pi | артефакт `file_set` / `agent_file_evidence` с низкой уверенностью | §6.2 |
| 46 | Сокращён контракт v1 §8 | восстановлены `POST /sessions`, `GET /sessions/{id}`, `GET /transactions` | §9.2 |
| 47 | Нет сравнения с коллегами (Vignette 3) | `developer_peer_baseline`, `delta_vs_peers` | §7.1 |
| 48 | Вмешательство без контроля выдавалось за причинность | `causality_level`, `control_value`, `ci_low/high`; `before_after` = `association` | §7.4 |
| 49 | Нет сущности запуска (`agent_settled`) | `runs` + `run_settlement` | §4.4, §11 |
| 50 | Контекст процесса адаптера не смоделирован | `adapter_instances` + `raw_events.adapter_instance_id` | §9.1 |
| 51 | `task_type` по умолчанию `other` маскировал отсутствие метки | поле nullable, `task_type_source`, `task_type_coverage.labeled_rate` | §7.1 |
| 52 | v1 задавал статусы задачи дважды и по-разному | пять состояний + маппинг `in_progress ↔ ACTIVE` | §11 |
| 53 | `outcome_link` подразумевался одиночным | множество связей в `task_artifacts`, массив ссылок в `transactions_outcome_links`; в проекции — лучший подтверждённый | §6.3 |
| 54 | Добавление артефакта позже могло затереть предыдущий | состояния `candidate/confirmed/superseded/rejected`, добавление только вперёд, единственный `is_primary` | §6.3 |
| 55 | Класс артефакта выбирался вручную и расходился с фактами | класс — максимум по `artifact_class_rank` среди подтверждённых; `class_source` показывает источник | §6.3 |

---

## 13. Проверка

Артефакты проверяются применением к чистому PostgreSQL:

```bash
docker run -d --name atm-schema-check -e POSTGRES_PASSWORD=x -e POSTGRES_DB=atm postgres:16-alpine
psql -v ON_ERROR_STOP=1 -f specs/schema.sql
psql -v ON_ERROR_STOP=1 -f specs/schema_smoke.sql
```

`schema_smoke.sql` вставляет задачу с двумя попытками в одном `retry_family_id`, расхождением
моделей, подписочным биллингом, артефактом и вердиктом, затем читает все представления петель.
Ожидаемый результат: `model_divergences` возвращает одну строку, `futile_retries` — один цикл с
повторяющимся контекстом, `policy_comparison` — стоимость и номинальную стоимость раздельно,
`fallback_rate` — 0.5, `developer_cohorts` — строку только при достижении пола когорты,
`context_breadth` — 2, 3 и 0 файлов по попыткам, `stage_conversion` — конверсию
`edit → verify = 1.0` и `repair → review = 0.0`, `developer_peer_baseline` — отклонения ±0.1 при двух
когортах, `run_settlement` — один закрытый и один открытый запуск.

Три проверки доказывают, что ограничения работают, а не просто объявлены: свёртка статуса,
обязательность `outcome` при закрытии и неизменяемость вытесненной строки.
