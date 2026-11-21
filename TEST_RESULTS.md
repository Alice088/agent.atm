# TEST_RESULTS

## Формат ведения

Новый прогон добавляется сверху, сразу под этим разделом, с заголовком
`## Прогон: YYYY-MM-DD HH:MM TZ (±HHMM)`. Результаты — только таблицей с колонками
`# | Тест | Пакет | Результат | Время`, где результат — `PASS`, `FAIL`, `SKIP` или `PANIC`.
После таблицы обязательны `### Сводка` и `### Падения`.

## Прогон: 2026-11-21 22:19 MSK (+0300)

Ветка: `master`. Go: `go1.27.4 linux/amd64`.
Команды: `go test ./... -count=1`; `psql -v ON_ERROR_STOP=1 -f specs/schema.sql`;
`psql -v ON_ERROR_STOP=1 -f specs/schema_smoke.sql` на `postgres:16-alpine`.
Цель: множественные артефакты (`task_artifacts`, состояния, `artifact_refs`,
`task_artifact_summary`, `task_outcome_resolved`, `transactions_outcome_links`).

| # | Тест | Пакет | Результат | Время |
|---|------|-------|-----------|-------|
| 1 | TestNew | internal/database | PASS | 0.00s |
| 2 | TestHealth | internal/database | PASS | 0.01s |
| 3 | TestClose | internal/database | PASS | 0.00s |
| 4 | TestHelloWorldHandler | internal/server | PASS | 0.00s |
| 5 | schema.sql apply on clean postgres:16 (exit 0, 0 ERROR) | specs | PASS | 0.46s |
| 6 | schema_smoke.sql full script (exit 0, 0 ERROR, 4 NOTICE) | specs | PASS | 0.12s |
| 7 | task_artifact_summary: 5 total, 4 active, 1 superseded | specs | PASS | 0.01s |
| 8 | task_artifact_summary.artifact_class = merged_pr from artifacts | specs | PASS | 0.01s |
| 9 | task_outcome_resolved.class_source = artifacts beats decision | specs | PASS | 0.01s |
| 10 | transactions_outcome_links: 4 refs, count matches length | specs | PASS | 0.01s |
| 11 | superseded file_set excluded from outcome_links | specs | PASS | 0.01s |
| 12 | artifact_refs builds repo@sha, repo#pr-n, ci:run, files:n | specs | PASS | 0.01s |
| 13 | task_artifacts_one_primary rejects second primary | specs | PASS | 0.01s |
| 14 | transactions_19.outcome_link = best confirmed ref | specs | PASS | 0.01s |
| 15 | status rollup constraint rejects success+timeout | specs | PASS | 0.01s |
| 16 | tasks_require_outcome blocks close without outcome | specs | PASS | 0.01s |
| 17 | tasks_require_outcome allows close with outcome | specs | PASS | 0.01s |
| 18 | superseded row is immutable | specs | PASS | 0.01s |
| 19 | transactions_19 returns 4 rows, in_flight has null status | specs | PASS | 0.01s |
| 20 | model_divergences reports 2 distinct models | specs | PASS | 0.01s |
| 21 | fallback_chain shows observed switches only | specs | PASS | 0.01s |
| 22 | developer_peer_baseline returns +0.1 / -0.1 | specs | PASS | 0.01s |
| 23 | task_type_coverage reports labeled_rate 0.83 and 1.00 | specs | PASS | 0.01s |
| 24 | run_settlement shows one settled and one open run | specs | PASS | 0.01s |
| 25 | policy_comparison separates metered and notional | specs | PASS | 0.01s |
| 26 | fallback_rate_by_policy returns 0.5 and 0.0 | specs | PASS | 0.01s |
| 27 | futile_retries flags repeated context fingerprint | specs | PASS | 0.01s |
| 28 | stage_conversion returns edit→verify 1.0, repair→review 0.0 | specs | PASS | 0.01s |
| 29 | context_breadth returns 2, 3, 0, 0 files | specs | PASS | 0.01s |
| 30 | developer_cohorts applies min_cohort_size floor | specs | PASS | 0.01s |
| 31 | intervention_effects stores did with control value | specs | PASS | 0.01s |
| 32 | task_sessions_active_per_session rejects second active binding | specs | PASS | 0.01s |

### Сводка

Всего: 32. PASS: 32. FAIL: 0. SKIP: 0. PANIC: 0. Время: 1.93s (тесты) + 0.58s (схема).

### Падения

Падений нет.

Замечание: четыре `NOTICE` в выводе smoke-скрипта — подтверждения срабатывания проверок
(свёртка статуса, обязательность `outcome`, неизменяемость вытесненной строки, единственный
основной артефакт), а не предупреждения СУБД.

## Прогон: 2026-11-21 22:14 MSK (+0300)

Ветка: `master`. Go: `go1.27.4 linux/amd64`.
Команды: `go test ./... -v -count=1`; `psql -v ON_ERROR_STOP=1 -f specs/schema.sql`;
`psql -v ON_ERROR_STOP=1 -f specs/schema_smoke.sql` на `postgres:16-alpine`.
Цель: проверка исправлений по 15 расхождениям (домены полей, триггеры, `runs`,
`adapter_instances`, `developer_peer_baseline`, `causality_level`, `classifier_mappings`).

| # | Тест | Пакет | Результат | Время |
|---|------|-------|-----------|-------|
| 1 | TestNew | internal/database | PASS | 0.00s |
| 2 | TestHealth | internal/database | PASS | 0.01s |
| 3 | TestClose | internal/database | PASS | 0.00s |
| 4 | TestHelloWorldHandler | internal/server | PASS | 0.00s |
| 5 | schema.sql apply on clean postgres:16 (exit 0, 0 ERROR) | specs | PASS | 0.42s |
| 6 | schema_smoke.sql full script (exit 0, 0 ERROR, 3 NOTICE) | specs | PASS | 0.12s |
| 7 | status rollup constraint rejects success+timeout | specs | PASS | 0.01s |
| 8 | tasks_require_outcome blocks close without outcome | specs | PASS | 0.01s |
| 9 | tasks_require_outcome allows close with outcome | specs | PASS | 0.01s |
| 10 | superseded row is immutable | specs | PASS | 0.01s |
| 11 | transactions_19 returns 4 rows, in_flight row has null status | specs | PASS | 0.01s |
| 12 | requested_model is physical model, virtual_model holds alias | specs | PASS | 0.01s |
| 13 | model_divergences reports 2 distinct models | specs | PASS | 0.01s |
| 14 | fallback_chain shows observed switches, configured prefix separate | specs | PASS | 0.01s |
| 15 | auth_mode domain stays api_key/oauth/unknown, provider_kind=local | specs | PASS | 0.01s |
| 16 | developer_peer_baseline returns delta +0.1 / -0.1 | specs | PASS | 0.01s |
| 17 | task_type_coverage reports labeled_rate 0.83 and 1.00 | specs | PASS | 0.01s |
| 18 | run_settlement shows one settled and one open run | specs | PASS | 0.01s |
| 19 | policy_comparison separates metered and notional | specs | PASS | 0.01s |
| 20 | fallback_rate_by_policy returns 0.5 and 0.0 | specs | PASS | 0.01s |
| 21 | futile_retries flags repeated context fingerprint | specs | PASS | 0.01s |
| 22 | stage_conversion returns edit→verify 1.0, repair→review 0.0 | specs | PASS | 0.01s |
| 23 | context_breadth returns 2, 3, 0, 0 files | specs | PASS | 0.01s |
| 24 | developer_cohorts applies min_cohort_size floor | specs | PASS | 0.01s |
| 25 | intervention_effects stores did with control value | specs | PASS | 0.01s |
| 26 | task_sessions_active_per_session rejects second active binding | specs | PASS | 0.01s |

### Сводка

Всего: 26. PASS: 26. FAIL: 0. SKIP: 0. PANIC: 0. Время: 1.95s (тесты) + 0.54s (схема).

### Падения

Падений нет.

Замечание: три `NOTICE` в выводе smoke-скрипта — это подтверждения срабатывания проверок (свёртка
статуса, обязательность `outcome`, неизменяемость вытесненной строки), а не предупреждения СУБД.

## Прогон: 2026-11-21 22:05 MSK (+0300)

Ветка: `master`. Go: `go1.27.4 linux/amd64`.
Команды: `go test ./... -count=1`; `psql -v ON_ERROR_STOP=1 -f specs/schema.sql`;
`psql -v ON_ERROR_STOP=1 -f specs/schema_smoke.sql` на `postgres:16-alpine`.
Цель прогона: проверка добавленных `attempt_context`, `context_breadth`, `stage_conversion`
и `abandonment_rate`.

| # | Тест | Пакет | Результат | Время |
|---|------|-------|-----------|-------|
| 1 | TestNew | internal/database | PASS | 0.00s |
| 2 | TestHealth | internal/database | PASS | 0.01s |
| 3 | TestClose | internal/database | PASS | 0.00s |
| 4 | TestHelloWorldHandler | internal/server | PASS | 0.00s |
| 5 | schema.sql apply on clean postgres:16 (exit 0, 0 ERROR:) | specs | PASS | 0.44s |
| 6 | schema_smoke.sql full script (exit 0, 0 ERROR:) | specs | PASS | 0.13s |
| 7 | task_sessions_active_per_session rejects second active binding | specs | PASS | 0.01s |
| 8 | transactions_19 projection returns 3 rows with 20 columns | specs | PASS | 0.01s |
| 9 | model_divergences detects gateway/transcript split | specs | PASS | 0.01s |
| 10 | policy_comparison separates metered and notional cost | specs | PASS | 0.01s |
| 11 | fallback_rate_by_policy returns 0.5 on 2 attempts | specs | PASS | 0.01s |
| 12 | futile_retries flags repeated context fingerprint | specs | PASS | 0.01s |
| 13 | developer_cohorts applies min_cohort_size floor | specs | PASS | 0.01s |
| 14 | context_breadth returns 2, 3 and 0 files per attempt | specs | PASS | 0.01s |
| 15 | stage_conversion returns edit→verify 1.0 and repair→review 0.0 | specs | PASS | 0.01s |
| 16 | developer_cohorts.abandonment_rate returns 0.0 | specs | PASS | 0.01s |

### Сводка

Всего: 16. PASS: 16. FAIL: 0. SKIP: 0. PANIC: 0. Время: 2.08s (тесты) + 0.74s (схема).

### Падения

Падений нет.

Замечание: `grep -c error` по выводу smoke-скрипта даёт совпадение на данных (`tool_error`,
`status = error`), а не на ошибке СУБД. Признак ошибки — ненулевой код возврата `psql`
и строка `ERROR:`; обе отсутствуют.

## Прогон: 2026-11-21 22:04 MSK (+0300)

Ветка: `master`. Go: `go1.27.4 linux/amd64`.
Команды: `go test ./... -v -count=1`; `psql -v ON_ERROR_STOP=1 -f specs/schema.sql`;
`psql -v ON_ERROR_STOP=1 -f specs/schema_smoke.sql` на `postgres:16-alpine`.

| # | Тест | Пакет | Результат | Время |
|---|------|-------|-----------|-------|
| 1 | TestNew | internal/database | PASS | 0.00s |
| 2 | TestHealth | internal/database | PASS | 0.01s |
| 3 | TestClose | internal/database | PASS | 0.00s |
| 4 | TestHelloWorldHandler | internal/server | PASS | 0.00s |
| 5 | schema.sql apply on clean postgres:16 | specs | PASS | 0.42s |
| 6 | schema_smoke.sql insert + 12 view queries | specs | PASS | 0.11s |
| 7 | task_sessions_active_per_session rejects second active binding | specs | PASS | 0.01s |
| 8 | transactions_19 projection returns 3 rows with 20 columns | specs | PASS | 0.01s |
| 9 | model_divergences detects gateway/transcript split | specs | PASS | 0.01s |
| 10 | policy_comparison separates metered and notional cost | specs | PASS | 0.01s |
| 11 | fallback_rate_by_policy returns 0.5 on 2 attempts | specs | PASS | 0.01s |
| 12 | futile_retries flags repeated context fingerprint | specs | PASS | 0.01s |
| 13 | developer_cohorts applies min_cohort_size floor | specs | PASS | 0.01s |

### Сводка

Всего: 13. PASS: 13. FAIL: 0. SKIP: 0. PANIC: 0. Время: 2.66s (тесты) + 0.60s (схема).

### Падения

Падений нет.

Замечание: `grep -c error` по выводу smoke-скрипта даёт совпадение на данных (`tool_error`,
`status = error`), а не на ошибке СУБД. Признак ошибки — ненулевой код возврата `psql`
и строка `ERROR:`; обе отсутствуют.
