# Runtime Trace

Observability for AI coding agents, measured per task rather than per artefact.

This repository implements the runtime transaction schema from *Tracing the Messy Middle: A
Runtime Transaction Schema for AI Coding Agents* (Hou, Li, Chen, Chen — [arXiv:2611.23234](https://arxiv.org/abs/2611.23234)).
`SPEC.md` is the normative document, `specs/schema.sql` is its executable form, `DESIGN.md`
describes the interface.

## The problem

Artefact datasets — commits, pull requests, passing tests — record only the work that
survived. A session where the agent hit a rate limit, sent a malformed tool call, fell back
to a cheaper model and gave up leaves nothing behind: no commit, no CI run, no trace. By
every artefact signal it did not happen. By every cost signal it did.

Three cases keep coming back:

- **The session that never existed.** Real spend, no commit. At runtime: rate limit, broken
  tool call, fallback to a cheaper model, wrong patch, several failed repairs, exit.
- **The saving that costs more.** A cost-aware policy routes large tasks to a cheaper
  provider. Per-request price drops 60 %. Two weeks later total spend is up, because the
  gateway saw the resolved model and the token count but not the retries.
- **The senior and the junior.** Same agent, same class of bug. The senior lands patches in
  two or three requests, the junior averages nine with three aborts. The difference is
  visible at runtime and invisible in any artefact.

In all three the information needed to fix things existed at runtime and was never captured.
The analytics are not the missing part — funnel analysis and A/B testing are old news. The
data substrate is.

Artefacts cannot supply it, because they are built from what agents leave behind. A session
that produces nothing leaves nothing to scrape, so the sample is biased towards surviving
work. Gateway logs know routing but not tasks; transcripts know sessions but not routing.
Neither knows whether the task produced an accepted artefact — which is the denominator of
cost per completed task.

## What it records

Five layers, from the outermost record inward. Gateway and transcript are reconciled
locally, before anything is aggregated.

![The AgentOps feedback architecture: what artefacts miss, the five layers that capture it, and the three loops they enable](docs/figures/fig1-agentops-architecture.png)

*Figure from the paper: artefact datasets on the left, the five-layer schema in the middle,
the three feedback loops on the right.*

| Layer | What it adds |
|---|---|
| Identity & session | pseudonymised developer, session id that survives switching agents |
| Task context | task, task type, project |
| Routing | policy, requested vs resolved model, fallback chain |
| Execution | timing, tokens, status, retry index, stage and action |
| Outcome | the artefact produced, if any, and how sure we are |

The unit of analysis is the task, not the request and not the span. Cost attribution and
outcome linkage both need a record that spans many LLM calls.

Each layer feeds one loop:

| Loop | Question | Views |
|---|---|---|
| Coaching | Where does this developer differ from peers on the same task type? | `developer_cohorts`, `developer_peer_baseline` |
| Workflow | At which stage do tasks die? | `stage_funnel`, `stage_conversion`, `turn_paths`, `futile_retries` |
| Routing | Did the task get cheaper, or only the request? | `policy_comparison`, `fallback_rate_by_policy` |

Two details make these computable rather than decorative. Per-developer aggregates join
`developer_cohorts`, so `min_cohort_size` applies inside the query and a result that would
resolve to one person returns no rows. And `fallback_rate` has a real denominator:
`policy_fallback_context` keeps the configured chain, because a fallback frequency without
"how many switches were possible" means nothing.

## Where it goes beyond the paper

The paper says what to capture. It does not say what to do when sources disagree, when a
value is missing, or when an artefact shows up after the task closed. Those cases are decided
here, with reasons, in `SPEC.md` (55 decisions).

| Gap | Decision |
|---|---|
| `resolved_model` when no answer arrived | `null` with `resolved_model_source = 'none'` — substituting the requested model would turn "no data" into "no substitution" |
| `requested_model` vs a policy alias | requested is the physical model; the alias is `virtual_model`; `model_divergence` fires only on two conflicting response-side observations |
| `fallback_chain`: observed or configured | projection carries `observed_fallback_chain`; the configured chain is a separate denominator |
| `retry_index` | `attempt_ordinal - 1` inside a retry family, not a transport retry |
| `auth_mode` mixing credentials and billing | three axes: `auth_mode`, `billing_mode`, `provider_kind`; billing is never inferred from auth |
| `outcome_type` mixing class, verdict and abandonment | two axes: `artifact_class` × `human_verdict`; abandoned becomes `linkage_state = 'timed_out'` |
| `outcome_link` as a single value | a many-to-many relation with states (below) |
| `cost_usd` mixing real and subscription money | `cost_usd_metered` and `cost_usd_notional`, never summed |
| "required at task close" as a convention | a deferred trigger; a task cannot be closed without an outcome |
| session identity assumed unique | `sessions.runtime_name`, plus one active task per session |

## The schema

Raw input is never overwritten, so a normaliser can be replayed without losing evidence.

```
agent → adapter → buffer → POST /events → raw_events → normalizer → transactions / actions / turns
                                                              ↓
                                            linker → artifacts → outcomes
                                                              ↓
                                                   views (metrics)
```

33 tables, 19 views, one materialised view. Grouped by layer:

| Layer | Tables |
|---|---|
| Identity & session | `developers`, `developer_consents`, `sessions`, `session_branches`, `adapters`, `adapter_instances` |
| Task context | `tasks`, `task_sessions`, `projects`, `task_type_coverage` |
| Routing | `policies`, `policy_assignments`, `experiments` |
| Execution | `raw_events`, `runtime_transactions`, `turns`, `actions`, `attempt_context`, `runs` |
| Outcome | `artifacts`, `task_artifacts`, `task_outcomes`, `artifact_class_rank` |
| Governance | `settings`, `classifier_versions`, `classifier_mappings`, `metric_definitions`, `retention_policies`, `redaction_rules` |

Derived rows carry the version of whatever produced them: `normalizer_version`,
`linker_version`, `taxonomy_version`. Changing a classifier must not rewrite history, or a
before/after comparison becomes impossible.

### The nineteen-field export

The table from the paper is the exchange format, not the storage limit. `transactions_19` is
a view; the table underneath is a superset. Nineteen rows give twenty columns: `in/out_tokens`
splits in two because input and output are not comparable across policies, while
`stage/action_type` stays folded, so the one-to-one correspondence with the paper holds.

| Field | Source | Note |
|---|---|---|
| `session_id` | `runtime_transactions.session_id` | |
| `developer_id` | `runtime_transactions.developer_id` | hashed by default |
| `agent_tool` | `runtime_transactions.agent_tool` | `pi`, `claude_code`, `codex`, `cursor` |
| `task_id` | `runtime_transactions.task_id` | |
| `task_type` | `tasks.task_type` | nullable; `unset` is recorded, not defaulted silently |
| `project` | `tasks.project_id` | |
| `auth_mode` | `runtime_transactions.auth_mode` | credentials only |
| `policy_id` | `runtime_transactions.policy_id` | pinned per attempt |
| `requested_model` | `runtime_transactions.requested_model` | request-side fact |
| `resolved_model` | `runtime_transactions.resolved_model` | response-side fact, `null` if absent |
| `fallback_chain` | `observed_fallback_chain` | observed switches only |
| `request_ts` | `runtime_transactions.request_ts` | written at request start, not at response |
| `in/out_tokens` | `input_tokens` / `output_tokens` | |
| `status` | `runtime_transactions.status` | `null` while in flight |
| `retry_index` | `attempt_ordinal - 1` | within a retry family |
| `stage/action_type` | `stage \|\| '/' \|\| action_type` | |
| `cost_usd` | `runtime_transactions.cost_usd` | split by billing mode in aggregates |
| `outcome_link` | `task_artifact_summary.primary_ref` | best confirmed artefact |
| `outcome_type` | `task_outcome_resolved.artifact_class` | taken from artefacts when they exist |

Fields outside the projection are not lost — they stay in `runtime_transactions` and the
related tables, available to queries but not to the compatible export.

### Several artefacts per task

A task collects artefacts over time, and that is the normal case: a file set at session end,
one or more commits hours later, a CI run after a commit, a pull request and its merge days
later. Treating the outcome as a single value asserted at close throws away exactly the
history that shows whether the task landed.

The link is many-to-many and every link has a state.

| State | Meaning |
|---|---|
| `candidate` | a trace awaiting confirmation, e.g. a file list from the agent |
| `confirmed` | counted towards the task's class |
| `superseded` | replaced by a stronger artefact, pointing at its replacement |
| `rejected` | a false match, kept with its reason |

The task's class is the best confirmed artefact under a fixed order: `merged_pr`,
`committed_patch`, `multi_session`, `passing_unreviewed`, `partial_artifact`, `none`. The
class a human set in `task_outcomes` stays as the decision taken at close, and
`task_outcome_resolved.class_source` says which of the two produced the value. Without this
the class would freeze at close, and a PR merged two days later would never reach the
cost-per-completed-task denominator.

References are derived, not stored as free text: `repo@sha` for a commit, `repo#pr-42` for a
pull request, `ci:run-778` for a CI run, `files:2` for a file set. The projection carries one
reference, as the paper's field type requires; `transactions_outcome_links.outcome_links`
carries the array, and superseded links stay visible in `task_artifact_summary.all_artifact_refs`.

### What the database guarantees

Obligations written in prose get forgotten under deadline.

| Invariant | Mechanism |
|---|---|
| a closed task has an outcome | deferred constraint trigger `tasks_require_outcome` |
| a superseded transaction is immutable | trigger `runtime_transactions_superseded_immutable` |
| a status cannot be success and timeout at once | check over `status`, `status_detail`, `status_phase` |
| one primary artefact per task | partial unique index `task_artifacts_one_primary` |
| one active task per session | partial unique index `task_sessions_active_per_session` |
| an aggregate never resolves to one person | `min_cohort_size` inside the cohort views |

Metric definitions (formula, unit, granularity, whether the cohort floor applies) live in
`metric_definitions`, so a number and its definition cannot drift apart. That one is a
convention, not a constraint.

## What is checked

`specs/schema_smoke.sql` loads one task of each interesting shape — a run that succeeded with
fallbacks, one rate-limited mid-flight, one where gateway and transcript disagree about the
model, one closed before its artefact appeared — then reads every view and attacks every
constraint. It runs on a clean `postgres:16-alpine`; the latest run with timings is in
`TEST_RESULTS.md`.

| Observation | Result |
|---|---|
| rows in `transactions_19`, one with `status = NULL` (in flight) | 4 |
| models seen for the same requests | 2 (gateway and transcript disagree) |
| `fallback_rate` by policy | 0.5 and 0.0, with configured chains as denominators |
| `stage_conversion` edit→verify / repair→review | 1.0 / 0.0 |
| `developer_peer_baseline` | ±0.1 against the cohort |
| `task_type_coverage.labeled_rate` | 0.83 and 1.00 |
| artefacts on one task: 2 commits, a PR, a CI run, a file set | 5 total, 4 active, 1 superseded |
| class after the PR merges | `merged_pr` from artefacts, the stored decision being `committed_patch` |
| constraint attacks | four raised, none silently accepted |

This is a fixture, not a deployment study. It shows the model computes what it claims and
that the constraints fire. It says nothing about whether the loops improve anything — the
same caveat the paper attaches to its own probe.

## Limits and privacy

Local transcripts hold source code, paths and prompts that may include credentials. Keeping
aggregation local is not enough on its own: turn counts, retry rates and per-developer cost
are productivity signals that invite misuse. The paper's deployment defaults are settings
here rather than documentation — `developer_id_storage` (`hashed` by default,
`plaintext_local` available), `capture_content` (`metadata_only` by default, `none` and
`full_local` available), the `min_cohort_size` floor, retention on raw events. A prohibition
that is not a setting gets worked around, so both original capabilities survive as explicit
modes with safe defaults.

The paper names three open problems. This schema does not solve them; it makes them
measurable and records the inputs they will need.

- **Reconciliation without shared ids.** Probabilistic matching on timestamp, model and token
  counts. The agent setting adds a twist: a transcript entry may have no gateway record
  because the agent ran on a subscription, so absence is a finding, not a failed join.
  False-, missed- and ambiguous-match rates are not measured here.
- **Outcome linking across async systems.** Window, confidence, match features and linker
  version are recorded per link, and late artefacts are handled, but the linker itself is
  not evaluated.
- **Intervention causality.** Estimates are stored with control values and intervals, and
  `causality_level` stops an association from being reported as a cause. Confounding by task
  mix and model updates remains.

Known gaps in this repository, recorded rather than papered over: the Core API is a skeleton;
`SET CONSTRAINTS` only works inside a transaction, so bulk task closure is untested;
peer-baseline weights are unvalidated; `details.modifiedFiles` as a source of file sets has
not been checked against real agent output; the immutability trigger may conflict with
retention deletion.

## Running it

Go 1.27+, PostgreSQL 16+, Docker.

| Variable | Purpose |
|---|---|
| `PORT` | Core API port |
| `APP_ENV` | environment name |
| `BLUEPRINT_DB_HOST`, `BLUEPRINT_DB_PORT` | PostgreSQL address |
| `BLUEPRINT_DB_DATABASE`, `BLUEPRINT_DB_SCHEMA` | database and schema |
| `BLUEPRINT_DB_USERNAME`, `BLUEPRINT_DB_PASSWORD` | credentials |

Runtime parameters live in `settings`, not in code: `min_cohort_size = 5`,
`linkage_window_hours = 72`, `abandonment_timeout_hours = 72`,
`reconciliation_window_seconds = 120`, `schema_version = 2.0.0`.

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f specs/schema.sql
```

Verify on a throwaway instance — the schema must apply cleanly and every constraint must fire:

```bash
docker run -d --name atm-schema-check -e POSTGRES_PASSWORD=x -e POSTGRES_DB=atm postgres:16-alpine
docker cp specs/schema.sql atm-schema-check:/tmp/schema.sql
docker exec atm-schema-check psql -U postgres -d atm -v ON_ERROR_STOP=1 -f /tmp/schema.sql
docker cp specs/schema_smoke.sql atm-schema-check:/tmp/smoke.sql
docker exec atm-schema-check psql -U postgres -d atm -v ON_ERROR_STOP=1 -f /tmp/smoke.sql
```

```bash
make all          # build and test
make build        # binary
make test         # go test ./...
make itest        # database integration tests
make docker-run   # PostgreSQL
make docker-down  # stop PostgreSQL
```

Endpoints implemented today: `GET /` for liveness, `GET /health` for database state. The
Core API contract is specified but not built — `POST /api/v1/events` (idempotent on
`event_key`), task lifecycle under `/api/v1/tasks`, `GET /api/v1/sessions/{id}`,
`GET /api/v1/transactions`, `GET /api/v1/metrics/{name}`.

| Symptom | Cause | Action |
|---|---|---|
| `db down` in `/health` | PostgreSQL unreachable | `make docker-run`; check `BLUEPRINT_DB_*` |
| task never reaches `completed` | linkage window still open | wait `linkage_window_hours`, or link the artefact explicitly |
| cost is zero | all traffic is subscription-authenticated | read `cost_usd_notional`, not `cost_usd_metered` |
| empty funnel | agent never declared `semantic_action` | check `adapters.capabilities` |
| empty cohort view | fewer than `min_cohort_size` tasks | governance floor, not an error |

## Paper

Yuelin Hou, Haorui Li, Lu Chen, Zhen Chen. *Tracing the Messy Middle: A Runtime Transaction
Schema for AI Coding Agents.* arXiv:2611.23234v1 [cs.SE], 11 August 2026.
<https://arxiv.org/abs/2611.23234>
