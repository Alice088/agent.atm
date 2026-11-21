INSERT INTO adapters (adapter_id, agent_tool, adapter_version, runtime_version, capabilities)
VALUES ('pi-adapter-1', 'pi', '2.0.0', '1.6.0',
        '{"agent_tool":"full","session_id":"full","task_id":"absent","resolved_model":"transcript_only","file_evidence":"partial"}');

INSERT INTO developers (developer_id, display_ref, hash_algorithm, salt_version) VALUES
    ('a3f2b9c1d8e0', '@gosha', 'hmac-sha256', 1),
    ('b7c1d2e3f4a5', '@mira', 'hmac-sha256', 1);

INSERT INTO projects (project_id, name, repo_remote, default_branch)
VALUES ('payments-api', 'payments-api', 'git@example.com:team/payments-api.git', 'main');

INSERT INTO policies (policy_id, policy_version, configured_chain, valid_from) VALUES
    ('cost-aware-v3', '3.1', '["sonnet-primary","fb-cheap","fb-local"]', '2026-05-01T00:00:00Z'),
    ('sonnet-primary', '1.0', '["sonnet-primary"]', '2026-05-01T00:00:00Z');

INSERT INTO experiments (experiment_id, unit_kind, arm_a, arm_b, salt, started_at)
VALUES ('routing-2026-05', 'task', 'cost-aware-v3@3.1', 'sonnet-primary@1.0', 'abc123', '2026-05-01T00:00:00Z');

INSERT INTO sessions (session_id, agent_tool, adapter_id, runtime_version, runtime_name, cwd, project_id, started_at, status, id_source, resolution_confidence)
SELECT 'sess-' || lpad(g::text, 4, '0'), 'pi', 'pi-adapter-1', '1.6.0', '@earendil-works/pi-coding-agent',
       '/home/dev/payments-api', 'payments-api', '2026-05-12T09:00:00Z', 'ended', 'session_header', 1.00
FROM generate_series(1287, 1291) AS g;

INSERT INTO sessions (session_id, agent_tool, adapter_id, runtime_version, runtime_name, cwd, project_id, started_at, status, id_source, resolution_confidence)
SELECT 'sess-' || lpad(g::text, 4, '0'), 'pi', 'pi-adapter-1', '1.6.0', '@earendil-works/pi-coding-agent',
       '/home/dev/payments-api', 'payments-api', '2026-05-13T09:00:00Z', 'ended', 'session_header', 1.00
FROM generate_series(2001, 2005) AS g;

INSERT INTO session_branches (branch_id, session_id, is_head) VALUES
    ('sess-1287/head', 'sess-1287', true);

INSERT INTO adapter_instances (instance_id, adapter_id, agent_tool, pid, host, cwd_hash, session_id, started_at, heartbeat_at, state) VALUES
    ('ai-1', 'pi-adapter-1', 'pi', 4242, 'dev-box', 'h-cwd-1', 'sess-1287', '2026-05-12T08:59:00Z', '2026-05-12T09:45:00Z', 'ended'),
    ('ai-2', 'pi-adapter-1', 'pi', 4343, 'dev-box', 'h-cwd-1', 'sess-1289', '2026-05-12T10:00:00Z', '2026-05-12T10:05:00Z', 'running');

INSERT INTO runs (run_id, session_id, adapter_instance_id, started_at, settled_at, outcome, boundary_event) VALUES
    ('run-1287', 'sess-1287', 'ai-1', '2026-05-12T09:14:00Z', '2026-05-12T09:20:00Z', 'settled', 'agent_settled'),
    ('run-1289', 'sess-1289', 'ai-2', '2026-05-12T10:00:00Z', NULL, 'unknown', NULL);

INSERT INTO tasks (task_id, title, project_id, developer_id, task_type, task_type_source, taxonomy_version, policy_id, policy_version, status, started_at)
SELECT 'TASK-' || lpad(g::text, 4, '0'), 'task ' || g, 'payments-api', 'a3f2b9c1d8e0', 'bug_fix', 'manual', '2.0.0', 'cost-aware-v3', '3.1', 'in_progress', '2026-05-12T09:00:00Z'
FROM generate_series(1287, 1291) AS g;

INSERT INTO tasks (task_id, title, project_id, developer_id, task_type, task_type_source, taxonomy_version, policy_id, policy_version, status, started_at)
SELECT 'TASK-' || lpad(g::text, 4, '0'), 'peer task ' || g, 'payments-api', 'b7c1d2e3f4a5', 'bug_fix', 'manual', '2.0.0', 'sonnet-primary', '1.0', 'in_progress', '2026-05-13T09:00:00Z'
FROM generate_series(2001, 2005) AS g;

INSERT INTO tasks (task_id, title, project_id, developer_id, task_type, task_type_source, taxonomy_version, status, started_at)
VALUES ('TASK-3001', 'unlabeled task', 'payments-api', 'a3f2b9c1d8e0', NULL, 'unset', '2.0.0', 'in_progress', '2026-05-12T11:00:00Z');

INSERT INTO task_sessions (task_id, session_id, bound_at, binding_source)
SELECT 'TASK-' || lpad(g::text, 4, '0'), 'sess-' || lpad(g::text, 4, '0'), '2026-05-12T09:00:00Z', 'manual'
FROM generate_series(1287, 1291) AS g;

INSERT INTO task_sessions (task_id, session_id, bound_at, binding_source)
SELECT 'TASK-' || lpad(g::text, 4, '0'), 'sess-' || lpad(g::text, 4, '0'), '2026-05-13T09:00:00Z', 'manual'
FROM generate_series(2001, 2005) AS g;

INSERT INTO policy_assignments (task_id, experiment_id, arm, assignment_basis)
SELECT 'TASK-' || lpad(g::text, 4, '0'), 'routing-2026-05', 'cost-aware-v3@3.1', 'hash_of_task_id'
FROM generate_series(1287, 1291) AS g;

INSERT INTO turns (turn_id, session_id, branch_id, task_id, run_id, turn_seq, started_at, ended_at, outcome)
VALUES ('turn-1', 'sess-1287', 'sess-1287/head', 'TASK-1287', 'run-1287', 1, '2026-05-12T09:14:00Z', '2026-05-12T09:20:00Z', 'completed');

INSERT INTO runtime_transactions (
    transaction_id, session_id, task_id, branch_id, turn_id, run_id, adapter_instance_id,
    developer_id, agent_tool, attempt_ordinal, retry_family_id, parent_transaction_id,
    context_fingerprint, auth_mode, auth_source, billing_mode, provider_kind,
    policy_id, policy_version, policy_source, fallback_step, observed_fallback_chain,
    virtual_model, requested_model, resolved_model, resolved_model_source,
    resolved_model_transcript, resolved_model_gateway, model_divergence,
    request_ts, response_ts, duration_ms, input_tokens, output_tokens, cache_read_tokens,
    status, status_detail, status_phase, stage, action_type,
    cost_usd, cost_source, source_primary, source_secondary, match_confidence,
    linkage_state, taxonomy_version, normalizer_version, schema_version
) VALUES
('tx-1', 'sess-1287', 'TASK-1287', 'sess-1287/head', 'turn-1', 'run-1287', 'ai-1',
 'a3f2b9c1d8e0', 'pi', 1, 'rf-1', NULL,
 'ctx-a', 'oauth', 'stored', 'subscription', 'hosted',
 'cost-aware-v3', '3.1', 'gateway_config', 1, '[]'::jsonb,
 'sonnet-primary', 'claude-sonnet-4-6', 'claude-sonnet-4-6', 'transcript',
 'claude-sonnet-4-6', NULL, FALSE,
 '2026-05-12T09:14:03Z', '2026-05-12T09:14:41Z', 38000, 9812, 1204, 4000,
 'success', 'success', 'terminal', 'edit', 'llm_response',
 0.0421, 'computed', 'hook', 'jsonl', 0.97,
 'reconciled', '2.0.0', '2.0.0', '2.0.0'),
('tx-2', 'sess-1287', 'TASK-1287', 'sess-1287/head', 'turn-1', 'run-1287', 'ai-1',
 'a3f2b9c1d8e0', 'pi', 2, 'rf-1', 'tx-1',
 'ctx-a', 'oauth', 'stored', 'subscription', 'hosted',
 'cost-aware-v3', '3.1', 'gateway_config', 2, '["sonnet-primary","fb-cheap"]'::jsonb,
 'sonnet-primary', 'claude-sonnet-4-6', 'claude-sonnet-4-6', 'transcript',
 'claude-sonnet-4-6', 'minimax-m2.7', TRUE,
 '2026-05-12T09:14:50Z', '2026-05-12T09:15:20Z', 30000, 9812, 980, 4000,
 'rate_limited', 'rate_limited', 'terminal', 'repair', 'llm_response',
 0.0390, 'computed', 'hook', 'gateway', 0.91,
 'ambiguous', '2.0.0', '2.0.0', '2.0.0'),
('tx-3', 'sess-1288', 'TASK-1288', 'sess-1287/head', 'turn-1', 'run-1287', 'ai-1',
 'a3f2b9c1d8e0', 'pi', 1, NULL, NULL,
 'ctx-b', 'api_key', 'environment', 'metered', 'hosted',
 'sonnet-primary', '1.0', 'external', 1, '[]'::jsonb,
 NULL, 'claude-sonnet-4-6', 'claude-sonnet-4-6', 'gateway',
 'claude-sonnet-4-6', 'claude-sonnet-4-6', FALSE,
 '2026-05-12T10:00:00Z', '2026-05-12T10:00:30Z', 30000, 5000, 800, 0,
 'success', 'success', 'terminal', 'deliver', 'llm_response',
 0.0210, 'provider_reported', 'gateway', NULL, 1.00,
 'single_source', '2.0.0', '2.0.0', '2.0.0'),
('tx-4', 'sess-1289', 'TASK-1289', NULL, NULL, 'run-1289', 'ai-2',
 'a3f2b9c1d8e0', 'pi', 1, NULL, NULL,
 'ctx-c', 'unknown', NULL, 'free', 'local',
 NULL, NULL, NULL, NULL, '[]'::jsonb,
 NULL, NULL, NULL, 'none',
 NULL, NULL, NULL,
 '2026-05-12T10:02:00Z', NULL, NULL, NULL, NULL, NULL,
 NULL, 'unknown', 'in_flight', 'locate', 'llm_request',
 NULL, 'none', 'hook', NULL, NULL,
 'single_source', '2.0.0', '2.0.0', '2.0.0');

INSERT INTO actions (action_id, session_id, branch_id, task_id, turn_id, transaction_id, action_seq, ts, action_type, stage, tool_name, semantic_action, status, is_error, taxonomy_version, normalizer_version) VALUES
('act-1', 'sess-1287', 'sess-1287/head', 'TASK-1287', 'turn-1', 'tx-1', 1, '2026-05-12T09:14:03Z', 'llm_request', 'edit', 'read', 'read', 'success', FALSE, '2.0.0', '2.0.0'),
('act-2', 'sess-1287', 'sess-1287/head', 'TASK-1287', 'turn-1', 'tx-1', 2, '2026-05-12T09:14:44Z', 'tool_call', 'edit', 'edit', 'edit', 'success', FALSE, '2.0.0', '2.0.0'),
('act-3', 'sess-1287', 'sess-1287/head', 'TASK-1287', 'turn-1', 'tx-2', 3, '2026-05-12T09:14:55Z', 'tool_call', 'verify', 'bash', 'test', 'error', TRUE, '2.0.0', '2.0.0'),
('act-4', 'sess-1287', 'sess-1287/head', 'TASK-1287', 'turn-1', 'tx-2', 4, '2026-05-12T09:15:30Z', 'tool_error', 'repair', 'bash', 'test', 'error', TRUE, '2.0.0', '2.0.0');

INSERT INTO attempt_context (transaction_id, file_path_hash, bytes) VALUES
    ('tx-1', 'f1', 1200), ('tx-1', 'f2', 3400),
    ('tx-2', 'f1', 1200), ('tx-2', 'f2', 3400), ('tx-2', 'f3', 900);

INSERT INTO artifacts (artifact_id, kind, repo_remote, commit_sha, branch, pr_number, ci_run_id, files, artifact_class, observed_at, observed_by, external_url) VALUES
    ('art-1', 'commit', 'git@example.com:team/payments-api.git', '9f3e2c1', 'fix/auth', NULL, NULL, '["internal/auth/token.go","internal/auth/token_test.go"]', 'committed_patch', '2026-05-12T09:41:00Z', 'git_hook', 'https://git.example.com/team/payments-api/commit/9f3e2c1'),
    ('art-2', 'file_set', NULL, NULL, NULL, NULL, NULL, '["internal/auth/token.go","internal/auth/token_test.go"]', 'partial_artifact', '2026-05-12T09:20:00Z', 'agent_tool', NULL),
    ('art-3', 'commit', 'git@example.com:team/payments-api.git', 'a1b2c3d', 'fix/auth', NULL, NULL, '["internal/auth/token.go"]', 'committed_patch', '2026-05-12T10:12:00Z', 'git_hook', 'https://git.example.com/team/payments-api/commit/a1b2c3d'),
    ('art-4', 'pr', 'git@example.com:team/payments-api.git', NULL, 'fix/auth', 42, NULL, '[]', 'merged_pr', '2026-05-14T08:00:00Z', 'pr_sync', 'https://git.example.com/team/payments-api/pull/42'),
    ('art-5', 'ci_run', 'git@example.com:team/payments-api.git', '9f3e2c1', NULL, NULL, 'run-778', '[]', 'passing_unreviewed', '2026-05-12T09:50:00Z', 'ci', 'https://ci.example.com/runs/778');

INSERT INTO task_artifacts (task_id, artifact_id, link_method, linked_at, link_confidence, match_features, linker_version, state, is_primary, superseded_by_artifact_id, note) VALUES
    ('TASK-1287', 'art-1', 'git_commit_match', '2026-05-12T09:42:00Z', 0.88, '{"repo":true,"branch":true,"files":2,"time_delta_s":120}', '2.0.0', 'confirmed', TRUE, NULL, NULL),
    ('TASK-1287', 'art-2', 'agent_file_evidence', '2026-05-12T09:21:00Z', 0.30, '{"files":2,"source":"details.modifiedFiles"}', '2.0.0', 'superseded', FALSE, 'art-1', 'заменён коммитом'),
    ('TASK-1287', 'art-3', 'git_commit_match', '2026-05-12T10:13:00Z', 0.84, '{"repo":true,"branch":true,"files":1}', '2.0.0', 'confirmed', FALSE, NULL, 'второй коммит той же задачи'),
    ('TASK-1287', 'art-4', 'pr_merge_match', '2026-05-14T08:05:00Z', 0.95, '{"repo":true,"pr":42,"contains_commits":2}', '2.0.0', 'confirmed', FALSE, NULL, NULL),
    ('TASK-1287', 'art-5', 'ci_run_match', '2026-05-12T09:51:00Z', 0.90, '{"commit":"9f3e2c1","conclusion":"success"}', '2.0.0', 'confirmed', FALSE, NULL, NULL);

INSERT INTO task_outcomes (outcome_id, task_id, artifact_class, human_verdict, linkage_state, decided_at, decided_by)
VALUES ('out-1', 'TASK-1287', 'committed_patch', 'success', 'linked', '2026-05-12T09:45:00Z', 'a3f2b9c1d8e0');

INSERT INTO interventions (intervention_id, kind, scope_kind, scope_ref, applied_at, params, hypothesis, taxonomy_version)
VALUES ('int-1', 'plan_first', 'developer', 'a3f2b9c1d8e0', '2026-05-20T00:00:00Z', '{"template":"plan-before-edit"}', 'план до первой правки снижает циклы починки', '2.0.0');

INSERT INTO intervention_effects (intervention_id, metric, baseline_from, baseline_to, post_from, post_to, baseline_value, post_value, baseline_n, post_n, method, task_mix_adjusted, causality_level, control_value, control_n, effect_estimate, ci_low, ci_high)
VALUES ('int-1', 'repair_loops', '2026-05-01T00:00:00Z', '2026-05-19T00:00:00Z', '2026-05-21T00:00:00Z', '2026-06-10T00:00:00Z', 3.10, 2.40, 24, 22, 'did', TRUE, 'causal', 2.95, 21, -0.55, -1.20, 0.10);

REFRESH MATERIALIZED VIEW task_metrics;

SELECT count(*) AS transactions_19_rows FROM transactions_19;

SELECT task_id, artifacts_count, confirmed_count, candidate_count, active_count, artifact_class, primary_ref, artifact_kinds FROM task_artifact_summary ORDER BY task_id;

SELECT task_id, artifact_class, class_source, human_verdict, artifacts_count FROM task_outcome_resolved WHERE task_id = 'TASK-1287';

SELECT transaction_id, outcome_link, outcome_link_count, outcome_links FROM transactions_outcome_links ORDER BY transaction_id;

SELECT artifact_id, kind, ref FROM artifact_refs ORDER BY artifact_id;

DO $$
DECLARE msg text := 'no exception';
BEGIN
    BEGIN
        UPDATE task_artifacts SET is_primary = TRUE WHERE task_id = 'TASK-1287' AND artifact_id = 'art-3';
    EXCEPTION WHEN OTHERS THEN
        msg := SQLERRM;
    END;
    IF position('task_artifacts_one_primary' in msg) = 0 THEN
        RAISE EXCEPTION 'single primary constraint did not fire: %', msg;
    END IF;
    RAISE NOTICE 'single primary constraint fired';
END $$;

SELECT transaction_id, status, status_phase, status_detail FROM runtime_transactions ORDER BY transaction_id;

SELECT session_id, requested_model, resolved_model, retry_index, stage_action_type, outcome_type, fallback_chain
FROM transactions_19 ORDER BY request_ts;

SELECT transaction_id, virtual_model, requested_model FROM runtime_transactions ORDER BY transaction_id;

SELECT session_id, requested_model, resolved_model_transcript, resolved_model_gateway, distinct_models
FROM model_divergences;

SELECT transaction_id, fallback_step, observed_fallback_chain, configured_chain_prefix FROM policy_fallback_context ORDER BY transaction_id;

SELECT policy_id, policy_version, tasks, tasks_completed, cost_per_completed_task, notional_cost_per_completed_task FROM policy_comparison;

SELECT policy_id, policy_version, attempts, fallback_attempts, fallback_rate FROM fallback_rate_by_policy ORDER BY policy_id;

SELECT retry_family_id, attempts, distinct_contexts, futile_attempts FROM futile_retries;

SELECT path, has_repair, has_error, has_test FROM turn_paths;

SELECT developer_id, task_type, tasks, tasks_completed, completed_rate, abandonment_rate FROM developer_cohorts ORDER BY developer_id;

SELECT developer_id, task_type, completed_rate, task_type_completed_rate, delta_vs_peers, peer_cohorts FROM developer_peer_baseline ORDER BY developer_id;

SELECT developer_id, tasks, tasks_labeled, labeled_rate FROM task_type_coverage ORDER BY developer_id;

SELECT run_id, outcome, is_settled, transactions FROM run_settlement ORDER BY run_id;

SELECT from_stage, to_stage, tasks_reached, tasks_converted, conversion FROM stage_conversion WHERE tasks_reached > 0;

SELECT transaction_id, files_in_context, context_bytes FROM context_breadth ORDER BY transaction_id;

SELECT agent_tool, source_primary, linkage_state, transactions FROM capture_quality ORDER BY source_primary, linkage_state;

SELECT method, causality_level, effect_estimate, control_value FROM intervention_effects;

DO $$
DECLARE msg text := 'no exception';
BEGIN
    BEGIN
        INSERT INTO runtime_transactions (transaction_id, session_id, agent_tool, auth_mode, billing_mode, resolved_model_source, status, status_detail, status_phase, cost_source, source_primary, taxonomy_version, normalizer_version, schema_version)
        VALUES ('tx-bad-rollup', 'sess-1287', 'pi', 'oauth', 'metered', 'none', 'success', 'timeout', 'terminal', 'none', 'hook', '2.0.0', '2.0.0', '2.0.0');
    EXCEPTION WHEN OTHERS THEN
        msg := SQLERRM;
    END;
    IF position('status_rollup' in msg) = 0 THEN
        RAISE EXCEPTION 'rollup constraint did not fire: %', msg;
    END IF;
    RAISE NOTICE 'status rollup constraint fired';
END $$;

DO $$
DECLARE msg text := 'no exception';
BEGIN
    EXECUTE 'SET CONSTRAINTS tasks_require_outcome IMMEDIATE';
    BEGIN
        UPDATE tasks SET closed_at = '2026-05-12T12:00:00Z' WHERE task_id = 'TASK-1289';
    EXCEPTION WHEN OTHERS THEN
        msg := SQLERRM;
    END;
    IF position('closed without outcome' in msg) = 0 THEN
        RAISE EXCEPTION 'outcome enforcement did not fire: %', msg;
    END IF;
    RAISE NOTICE 'outcome enforcement fired';
END $$;

INSERT INTO task_outcomes (outcome_id, task_id, artifact_class, human_verdict, linkage_state, decided_at, decided_by)
VALUES ('out-2', 'TASK-1288', 'none', 'failure', 'not_applicable', '2026-05-12T10:10:00Z', 'a3f2b9c1d8e0');

UPDATE tasks SET status = 'completed', closed_at = '2026-05-12T10:10:00Z' WHERE task_id = 'TASK-1288';

SELECT task_id, status, closed_at IS NOT NULL AS closed FROM tasks WHERE task_id = 'TASK-1288';

INSERT INTO runtime_transactions (transaction_id, session_id, task_id, agent_tool, auth_mode, billing_mode, resolved_model_source, status, status_detail, status_phase, cost_source, source_primary, taxonomy_version, normalizer_version, schema_version)
VALUES ('tx-5', 'sess-1291', 'TASK-1291', 'pi', 'oauth', 'metered', 'none', 'success', 'success', 'terminal', 'none', 'hook', '2.0.0', '2.0.0', '2.0.0');

UPDATE runtime_transactions SET superseded_by = 'tx-1' WHERE transaction_id = 'tx-5';

DO $$
DECLARE msg text := 'no exception';
BEGIN
    BEGIN
        UPDATE runtime_transactions SET cost_usd = 1 WHERE transaction_id = 'tx-5';
    EXCEPTION WHEN OTHERS THEN
        msg := SQLERRM;
    END;
    IF position('is superseded and immutable' in msg) = 0 THEN
        RAISE EXCEPTION 'superseded immutability did not fire: %', msg;
    END IF;
    RAISE NOTICE 'superseded immutability fired';
END $$;
