CREATE TABLE settings (
    key text PRIMARY KEY,
    value text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO settings (key, value) VALUES
    ('min_cohort_size', '5'),
    ('linkage_window_hours', '72'),
    ('abandonment_timeout_hours', '72'),
    ('reconciliation_window_seconds', '120'),
    ('schema_version', '2.0.0'),
    ('normalizer_version', '2.0.0'),
    ('linker_version', '2.0.0'),
    ('taxonomy_version', '2.0.0'),
    ('developer_id_storage', 'hashed'),
    ('capture_content', 'metadata_only');

CREATE TABLE classifier_versions (
    kind text NOT NULL,
    version text NOT NULL,
    definition jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (kind, version)
);

CREATE TABLE classifier_values (
    kind text NOT NULL,
    version text NOT NULL,
    value text NOT NULL,
    is_terminal boolean NOT NULL DEFAULT false,
    semantic_group text,
    PRIMARY KEY (kind, version, value),
    FOREIGN KEY (kind, version) REFERENCES classifier_versions (kind, version)
);

INSERT INTO classifier_versions (kind, version, definition) VALUES
    ('task_type', '2.0.0', '{"axis":"intent"}'),
    ('stage', '2.0.0', '{"axis":"workflow_stage","derivation":"state_machine"}'),
    ('action_type', '2.0.0', '{"axis":"event"}'),
    ('status', '2.0.0', '{"axis":"request_outcome","domain":"v1_closed"}'),
    ('status_detail', '2.0.0', '{"axis":"request_outcome_fine"}'),
    ('status_phase', '2.0.0', '{"axis":"request_lifecycle"}'),
    ('provider_kind', '2.0.0', '{"axis":"provider_hosting"}'),
    ('run_outcome', '2.0.0', '{"axis":"run_settlement"}'),
    ('artifact_class', '2.0.0', '{"axis":"artifact_linkage"}'),
    ('human_verdict', '2.0.0', '{"axis":"human_judgment"}'),
    ('linkage_state', '2.0.0', '{"axis":"linkage_progress"}'),
    ('auth_mode', '2.0.0', '{"axis":"credential"}'),
    ('billing_mode', '2.0.0', '{"axis":"billing"}'),
    ('semantic_action', '2.0.0', '{"axis":"tool_semantics"}');

INSERT INTO classifier_values (kind, version, value, semantic_group) VALUES
    ('task_type', '2.0.0', 'feature_development', 'build'),
    ('task_type', '2.0.0', 'bug_fix', 'fix'),
    ('task_type', '2.0.0', 'refactoring', 'change'),
    ('task_type', '2.0.0', 'testing', 'verify'),
    ('task_type', '2.0.0', 'code_review', 'review'),
    ('task_type', '2.0.0', 'code_analysis', 'understand'),
    ('task_type', '2.0.0', 'documentation', 'write'),
    ('task_type', '2.0.0', 'configuration', 'ops'),
    ('task_type', '2.0.0', 'migration', 'change'),
    ('task_type', '2.0.0', 'performance_optimization', 'change'),
    ('task_type', '2.0.0', 'security', 'fix'),
    ('task_type', '2.0.0', 'other', 'unknown');

INSERT INTO classifier_values (kind, version, value, semantic_group) VALUES
    ('stage', '2.0.0', 'frame', 'understand'),
    ('stage', '2.0.0', 'locate', 'understand'),
    ('stage', '2.0.0', 'plan', 'understand'),
    ('stage', '2.0.0', 'edit', 'change'),
    ('stage', '2.0.0', 'verify', 'change'),
    ('stage', '2.0.0', 'repair', 'change'),
    ('stage', '2.0.0', 'review', 'deliver'),
    ('stage', '2.0.0', 'deliver', 'deliver'),
    ('stage', '2.0.0', 'unknown', 'unknown');

INSERT INTO classifier_values (kind, version, value, is_terminal) VALUES
    ('action_type', '2.0.0', 'user_input', false),
    ('action_type', '2.0.0', 'llm_request', false),
    ('action_type', '2.0.0', 'llm_response', false),
    ('action_type', '2.0.0', 'tool_call', false),
    ('action_type', '2.0.0', 'tool_result', false),
    ('action_type', '2.0.0', 'tool_error', false),
    ('action_type', '2.0.0', 'context_compaction', false),
    ('action_type', '2.0.0', 'branch_change', false),
    ('action_type', '2.0.0', 'model_selection', false),
    ('action_type', '2.0.0', 'transport_retry', false),
    ('action_type', '2.0.0', 'turn_start', false),
    ('action_type', '2.0.0', 'turn_end', false),
    ('action_type', '2.0.0', 'agent_completion', true),
    ('action_type', '2.0.0', 'agent_abort', true);

INSERT INTO classifier_values (kind, version, value, is_terminal) VALUES
    ('status', '2.0.0', 'success', true),
    ('status', '2.0.0', 'error', true),
    ('status', '2.0.0', 'timeout', true),
    ('status', '2.0.0', 'cancelled', true),
    ('status', '2.0.0', 'rate_limited', true),
    ('status', '2.0.0', 'unknown', true);

INSERT INTO classifier_values (kind, version, value, is_terminal) VALUES
    ('status_detail', '2.0.0', 'success', true),
    ('status_detail', '2.0.0', 'error_provider', true),
    ('status_detail', '2.0.0', 'error_client', true),
    ('status_detail', '2.0.0', 'timeout', true),
    ('status_detail', '2.0.0', 'cancelled', true),
    ('status_detail', '2.0.0', 'rate_limited', true),
    ('status_detail', '2.0.0', 'malformed_tool_call', true),
    ('status_detail', '2.0.0', 'context_overflow', true),
    ('status_detail', '2.0.0', 'unknown', true);

INSERT INTO classifier_values (kind, version, value, is_terminal) VALUES
    ('status_phase', '2.0.0', 'in_flight', false),
    ('status_phase', '2.0.0', 'terminal', true);

INSERT INTO classifier_values (kind, version, value) VALUES
    ('provider_kind', '2.0.0', 'hosted'),
    ('provider_kind', '2.0.0', 'local'),
    ('provider_kind', '2.0.0', 'unknown');

INSERT INTO classifier_values (kind, version, value, is_terminal) VALUES
    ('run_outcome', '2.0.0', 'settled', true),
    ('run_outcome', '2.0.0', 'aborted', true),
    ('run_outcome', '2.0.0', 'unknown', true);

CREATE TABLE classifier_mappings (
    kind text NOT NULL,
    from_version text NOT NULL,
    from_value text NOT NULL,
    to_version text NOT NULL,
    to_value text NOT NULL,
    PRIMARY KEY (kind, from_version, from_value, to_version, to_value)
);

INSERT INTO classifier_mappings (kind, from_version, from_value, to_version, to_value) VALUES
    ('status', '2.0.0', 'error', '2.0.0', 'error_provider'),
    ('status', '2.0.0', 'error', '2.0.0', 'error_client'),
    ('status', '2.0.0', 'error', '2.0.0', 'malformed_tool_call'),
    ('status', '2.0.0', 'error', '2.0.0', 'context_overflow'),
    ('status', '2.0.0', 'success', '2.0.0', 'success'),
    ('status', '2.0.0', 'timeout', '2.0.0', 'timeout'),
    ('status', '2.0.0', 'cancelled', '2.0.0', 'cancelled'),
    ('status', '2.0.0', 'rate_limited', '2.0.0', 'rate_limited'),
    ('status', '2.0.0', 'unknown', '2.0.0', 'unknown'),
    ('action_type', '1.0.0', 'retry', '2.0.0', 'transport_retry'),
    ('auth_mode', '1.0.0', 'local', '2.0.0', 'unknown');

INSERT INTO classifier_values (kind, version, value) VALUES
    ('artifact_class', '2.0.0', 'merged_pr'),
    ('artifact_class', '2.0.0', 'committed_patch'),
    ('artifact_class', '2.0.0', 'passing_unreviewed'),
    ('artifact_class', '2.0.0', 'partial_artifact'),
    ('artifact_class', '2.0.0', 'multi_session'),
    ('artifact_class', '2.0.0', 'none');

INSERT INTO classifier_values (kind, version, value) VALUES
    ('human_verdict', '2.0.0', 'success'),
    ('human_verdict', '2.0.0', 'partial_success'),
    ('human_verdict', '2.0.0', 'failure'),
    ('human_verdict', '2.0.0', 'abandoned'),
    ('human_verdict', '2.0.0', 'unknown');

INSERT INTO classifier_values (kind, version, value, is_terminal) VALUES
    ('linkage_state', '2.0.0', 'single_source', false),
    ('linkage_state', '2.0.0', 'reconciled', true),
    ('linkage_state', '2.0.0', 'ambiguous', true),
    ('linkage_state', '2.0.0', 'pending', false),
    ('linkage_state', '2.0.0', 'linked', true),
    ('linkage_state', '2.0.0', 'timed_out', true),
    ('linkage_state', '2.0.0', 'not_applicable', true);

INSERT INTO classifier_values (kind, version, value) VALUES
    ('auth_mode', '2.0.0', 'api_key'),
    ('auth_mode', '2.0.0', 'oauth'),
    ('auth_mode', '2.0.0', 'unknown');

INSERT INTO classifier_values (kind, version, value) VALUES
    ('billing_mode', '2.0.0', 'metered'),
    ('billing_mode', '2.0.0', 'subscription'),
    ('billing_mode', '2.0.0', 'free'),
    ('billing_mode', '2.0.0', 'unknown');

INSERT INTO classifier_values (kind, version, value) VALUES
    ('semantic_action', '2.0.0', 'read'),
    ('semantic_action', '2.0.0', 'search'),
    ('semantic_action', '2.0.0', 'edit'),
    ('semantic_action', '2.0.0', 'write'),
    ('semantic_action', '2.0.0', 'execute'),
    ('semantic_action', '2.0.0', 'test'),
    ('semantic_action', '2.0.0', 'build'),
    ('semantic_action', '2.0.0', 'vcs'),
    ('semantic_action', '2.0.0', 'network'),
    ('semantic_action', '2.0.0', 'delegate'),
    ('semantic_action', '2.0.0', 'other');

CREATE TABLE adapters (
    adapter_id text PRIMARY KEY,
    agent_tool text NOT NULL,
    adapter_version text NOT NULL,
    runtime_version text,
    capabilities jsonb NOT NULL,
    registered_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE developers (
    developer_id text PRIMARY KEY,
    display_ref text NOT NULL,
    hash_algorithm text NOT NULL,
    salt_version int NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE developer_consents (
    consent_id text PRIMARY KEY,
    developer_id text NOT NULL REFERENCES developers (developer_id),
    scope jsonb NOT NULL,
    granted_at timestamptz NOT NULL,
    revoked_at timestamptz,
    revocation_reason text
);

CREATE TABLE projects (
    project_id text PRIMARY KEY,
    name text NOT NULL,
    repo_remote text,
    repo_remote_hash text,
    default_branch text,
    external_ref text
);

CREATE TABLE policies (
    policy_id text NOT NULL,
    policy_version text NOT NULL,
    configured_chain jsonb NOT NULL,
    params jsonb NOT NULL DEFAULT '{}'::jsonb,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    PRIMARY KEY (policy_id, policy_version)
);

CREATE TABLE sessions (
    session_id text PRIMARY KEY,
    agent_tool text NOT NULL,
    adapter_id text REFERENCES adapters (adapter_id),
    runtime_version text,
    cwd text,
    project_id text REFERENCES projects (project_id),
    transcript_path text,
    runtime_name text,
    started_at timestamptz,
    ended_at timestamptz,
    status text NOT NULL DEFAULT 'unknown',
    id_source text NOT NULL,
    resolution_confidence numeric(3,2)
);

CREATE TABLE session_branches (
    branch_id text PRIMARY KEY,
    session_id text NOT NULL REFERENCES sessions (session_id),
    parent_branch_id text REFERENCES session_branches (branch_id),
    forked_at_entry_id text,
    is_head boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE adapter_instances (
    instance_id text PRIMARY KEY,
    adapter_id text NOT NULL REFERENCES adapters (adapter_id),
    agent_tool text NOT NULL,
    pid int,
    host text NOT NULL,
    cwd_hash text,
    session_id text REFERENCES sessions (session_id),
    started_at timestamptz NOT NULL,
    heartbeat_at timestamptz,
    state text NOT NULL
);

CREATE INDEX adapter_instances_live ON adapter_instances (agent_tool, cwd_hash) WHERE state = 'running';

CREATE TABLE runs (
    run_id text PRIMARY KEY,
    session_id text NOT NULL REFERENCES sessions (session_id),
    adapter_instance_id text REFERENCES adapter_instances (instance_id),
    started_at timestamptz,
    settled_at timestamptz,
    outcome text NOT NULL DEFAULT 'unknown',
    boundary_event text,
    UNIQUE (session_id, run_id)
);

CREATE TABLE tasks (
    task_id text PRIMARY KEY,
    title text,
    description text,
    project_id text REFERENCES projects (project_id),
    developer_id text REFERENCES developers (developer_id),
    task_type text,
    task_type_source text NOT NULL DEFAULT 'unset',
    task_type_confidence numeric(3,2),
    taxonomy_version text NOT NULL,
    policy_id text,
    policy_version text,
    status text NOT NULL DEFAULT 'pending',
    status_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    started_at timestamptz,
    closed_at timestamptz,
    abandonment_deadline timestamptz,
    FOREIGN KEY (policy_id, policy_version) REFERENCES policies (policy_id, policy_version)
);

CREATE TABLE task_sessions (
    task_id text NOT NULL REFERENCES tasks (task_id),
    session_id text NOT NULL REFERENCES sessions (session_id),
    bound_at timestamptz NOT NULL,
    unbound_at timestamptz,
    binding_source text NOT NULL,
    PRIMARY KEY (task_id, session_id, bound_at)
);

CREATE UNIQUE INDEX task_sessions_active_per_session ON task_sessions (session_id) WHERE unbound_at IS NULL;

CREATE TABLE experiments (
    experiment_id text PRIMARY KEY,
    unit_kind text NOT NULL,
    arm_a text NOT NULL,
    arm_b text NOT NULL,
    salt text NOT NULL,
    started_at timestamptz NOT NULL,
    ended_at timestamptz
);

CREATE TABLE policy_assignments (
    task_id text NOT NULL REFERENCES tasks (task_id),
    experiment_id text NOT NULL REFERENCES experiments (experiment_id),
    arm text NOT NULL,
    assigned_at timestamptz NOT NULL DEFAULT now(),
    assignment_basis text NOT NULL,
    PRIMARY KEY (task_id, experiment_id)
);

CREATE TABLE raw_events (
    event_id text PRIMARY KEY,
    event_key text NOT NULL UNIQUE,
    source text NOT NULL,
    adapter_id text REFERENCES adapters (adapter_id),
    adapter_instance_id text REFERENCES adapter_instances (instance_id),
    agent_tool text,
    session_id text,
    session_id_source text,
    session_resolution_state text NOT NULL DEFAULT 'pending',
    session_resolution_confidence numeric(3,2),
    task_id text,
    event_type text NOT NULL,
    event_ts timestamptz,
    event_seq bigint,
    clock_source text NOT NULL,
    ingested_at timestamptz NOT NULL DEFAULT now(),
    payload jsonb NOT NULL,
    redaction_report jsonb NOT NULL DEFAULT '{}'::jsonb,
    processed_at timestamptz,
    processor_version text,
    processing_attempts int NOT NULL DEFAULT 0,
    last_error text
);

CREATE INDEX raw_events_pending ON raw_events (ingested_at) WHERE processed_at IS NULL;
CREATE INDEX raw_events_session ON raw_events (session_id, event_seq);
CREATE INDEX raw_events_unresolved ON raw_events (session_resolution_state) WHERE session_resolution_state <> 'resolved';

CREATE TABLE clock_observations (
    observation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    adapter_id text REFERENCES adapters (adapter_id),
    source text NOT NULL,
    source_ts timestamptz NOT NULL,
    ingested_at timestamptz NOT NULL DEFAULT now(),
    skew_ms bigint
);

CREATE TABLE turns (
    turn_id text PRIMARY KEY,
    session_id text NOT NULL REFERENCES sessions (session_id),
    branch_id text REFERENCES session_branches (branch_id),
    task_id text REFERENCES tasks (task_id),
    run_id text REFERENCES runs (run_id),
    turn_seq bigint NOT NULL,
    started_at timestamptz,
    ended_at timestamptz,
    outcome text,
    entry_id text,
    UNIQUE (session_id, branch_id, turn_seq)
);

CREATE UNIQUE INDEX turns_session_unbranched ON turns (session_id, turn_seq) WHERE branch_id IS NULL;

CREATE TABLE runtime_transactions (
    transaction_id text PRIMARY KEY,
    session_id text NOT NULL REFERENCES sessions (session_id),
    task_id text REFERENCES tasks (task_id),
    branch_id text REFERENCES session_branches (branch_id),
    turn_id text REFERENCES turns (turn_id),
    developer_id text REFERENCES developers (developer_id),
    agent_tool text NOT NULL,
    attempt_ordinal int NOT NULL DEFAULT 1,
    retry_family_id text,
    parent_transaction_id text REFERENCES runtime_transactions (transaction_id),
    context_fingerprint text,
    adapter_instance_id text REFERENCES adapter_instances (instance_id),
    run_id text REFERENCES runs (run_id),
    auth_mode text NOT NULL,
    auth_source text,
    billing_mode text NOT NULL,
    provider_kind text NOT NULL DEFAULT 'unknown',
    policy_id text,
    policy_version text,
    policy_source text,
    fallback_step int,
    observed_fallback_chain jsonb,
    virtual_model text,
    requested_model text,
    resolved_model text,
    resolved_model_source text NOT NULL,
    resolved_model_transcript text,
    resolved_model_gateway text,
    model_divergence boolean,
    request_ts timestamptz,
    response_ts timestamptz,
    duration_ms bigint,
    input_tokens bigint,
    output_tokens bigint,
    cache_read_tokens bigint,
    cache_write_tokens bigint,
    reasoning_tokens bigint,
    status text,
    status_detail text NOT NULL,
    status_phase text NOT NULL DEFAULT 'terminal',
    stage text,
    action_type text,
    provider_retry_count int,
    cost_usd numeric(14,6),
    cost_source text NOT NULL,
    currency text NOT NULL DEFAULT 'USD',
    price_table_version text,
    source_primary text NOT NULL,
    source_secondary text,
    match_confidence numeric(3,2),
    linkage_state text NOT NULL DEFAULT 'single_source',
    taxonomy_version text NOT NULL,
    normalizer_version text NOT NULL,
    schema_version text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    superseded_by text REFERENCES runtime_transactions (transaction_id)
);

CREATE INDEX runtime_transactions_task ON runtime_transactions (task_id) WHERE superseded_by IS NULL;
CREATE INDEX runtime_transactions_session ON runtime_transactions (session_id, request_ts);
CREATE INDEX runtime_transactions_policy ON runtime_transactions (policy_id, policy_version);
CREATE INDEX runtime_transactions_retry ON runtime_transactions (retry_family_id) WHERE retry_family_id IS NOT NULL;
CREATE UNIQUE INDEX runtime_transactions_retry_ordinal ON runtime_transactions (retry_family_id, attempt_ordinal) WHERE retry_family_id IS NOT NULL;

ALTER TABLE runtime_transactions
    ADD CONSTRAINT runtime_transactions_status_domain
    CHECK (status IS NULL OR status IN ('success', 'error', 'timeout', 'cancelled', 'rate_limited', 'unknown')),
    ADD CONSTRAINT runtime_transactions_status_detail_domain
    CHECK (status_detail IN ('success', 'error_provider', 'error_client', 'timeout', 'cancelled', 'rate_limited', 'malformed_tool_call', 'context_overflow', 'unknown')),
    ADD CONSTRAINT runtime_transactions_status_phase_domain
    CHECK (status_phase IN ('in_flight', 'terminal')),
    ADD CONSTRAINT runtime_transactions_status_phase_consistent
    CHECK (
        (status_phase = 'in_flight' AND status IS NULL AND response_ts IS NULL)
        OR (status_phase = 'terminal' AND status IS NOT NULL)
    ),
    ADD CONSTRAINT runtime_transactions_status_rollup
    CHECK (
        (status_detail = 'success' AND status = 'success')
        OR (status_detail IN ('error_provider', 'error_client', 'malformed_tool_call', 'context_overflow') AND status = 'error')
        OR (status_detail IN ('timeout', 'cancelled', 'rate_limited', 'unknown') AND status = status_detail)
    ),
    ADD CONSTRAINT runtime_transactions_auth_mode_domain
    CHECK (auth_mode IN ('api_key', 'oauth', 'unknown')),
    ADD CONSTRAINT runtime_transactions_billing_mode_domain
    CHECK (billing_mode IN ('metered', 'subscription', 'free', 'unknown')),
    ADD CONSTRAINT runtime_transactions_resolved_model_source_domain
    CHECK (resolved_model_source IN ('gateway', 'transcript', 'none')),
    ADD CONSTRAINT runtime_transactions_cost_source_domain
    CHECK (cost_source IN ('provider_reported', 'computed', 'none')),
    ADD CONSTRAINT runtime_transactions_resolved_model_present
    CHECK ((resolved_model_source = 'none') = (resolved_model IS NULL));

CREATE TABLE actions (
    action_id text PRIMARY KEY,
    session_id text NOT NULL REFERENCES sessions (session_id),
    branch_id text REFERENCES session_branches (branch_id),
    task_id text REFERENCES tasks (task_id),
    turn_id text REFERENCES turns (turn_id),
    transaction_id text REFERENCES runtime_transactions (transaction_id),
    action_seq bigint NOT NULL,
    ts timestamptz,
    action_type text NOT NULL,
    stage text NOT NULL,
    tool_name text,
    semantic_action text,
    status text,
    is_error boolean,
    entry_id text,
    tool_call_id text,
    payload_bytes bigint,
    taxonomy_version text NOT NULL,
    normalizer_version text NOT NULL,
    UNIQUE (session_id, action_seq)
);

CREATE INDEX actions_task_stage ON actions (task_id, stage);
CREATE INDEX actions_semantic ON actions (task_id, semantic_action);

CREATE TABLE attempt_context (
    transaction_id text NOT NULL REFERENCES runtime_transactions (transaction_id),
    file_path_hash text NOT NULL,
    bytes bigint,
    PRIMARY KEY (transaction_id, file_path_hash)
);

CREATE VIEW context_breadth AS
SELECT
    rt.transaction_id,
    rt.task_id,
    rt.session_id,
    count(ac.file_path_hash) AS files_in_context,
    COALESCE(sum(ac.bytes), 0) AS context_bytes
FROM runtime_transactions rt
LEFT JOIN attempt_context ac ON ac.transaction_id = rt.transaction_id
WHERE rt.superseded_by IS NULL
GROUP BY rt.transaction_id, rt.task_id, rt.session_id;

CREATE TABLE artifacts (
    artifact_id text PRIMARY KEY,
    kind text NOT NULL,
    repo_remote text,
    commit_sha text,
    branch text,
    pr_number int,
    ci_run_id text,
    files jsonb NOT NULL DEFAULT '[]'::jsonb,
    artifact_class text,
    observed_at timestamptz NOT NULL,
    observed_by text NOT NULL,
    external_url text
);

CREATE UNIQUE INDEX artifacts_identity ON artifacts (kind, COALESCE(repo_remote, ''), COALESCE(commit_sha, ''), COALESCE(pr_number, 0), COALESCE(ci_run_id, ''));

CREATE TABLE artifact_class_rank (
    artifact_class text PRIMARY KEY,
    rank int NOT NULL
);

INSERT INTO artifact_class_rank (artifact_class, rank) VALUES
    ('merged_pr', 6),
    ('committed_patch', 5),
    ('multi_session', 4),
    ('passing_unreviewed', 3),
    ('partial_artifact', 2),
    ('none', 0);

CREATE TABLE task_artifacts (
    task_id text NOT NULL REFERENCES tasks (task_id),
    artifact_id text NOT NULL REFERENCES artifacts (artifact_id),
    link_method text NOT NULL,
    linked_at timestamptz NOT NULL,
    link_confidence numeric(3,2),
    match_features jsonb NOT NULL DEFAULT '{}'::jsonb,
    linker_version text NOT NULL,
    state text NOT NULL DEFAULT 'candidate',
    is_primary boolean NOT NULL DEFAULT false,
    superseded_by_artifact_id text REFERENCES artifacts (artifact_id),
    note text,
    PRIMARY KEY (task_id, artifact_id)
);

CREATE UNIQUE INDEX task_artifacts_one_primary ON task_artifacts (task_id) WHERE is_primary;
CREATE INDEX task_artifacts_by_task ON task_artifacts (task_id, state);

CREATE TABLE task_outcomes (
    outcome_id text PRIMARY KEY,
    task_id text NOT NULL REFERENCES tasks (task_id),
    artifact_class text NOT NULL,
    human_verdict text NOT NULL,
    linkage_state text NOT NULL,
    decided_at timestamptz NOT NULL,
    decided_by text,
    note text,
    superseded_by text REFERENCES task_outcomes (outcome_id)
);

CREATE UNIQUE INDEX task_outcomes_current ON task_outcomes (task_id) WHERE superseded_by IS NULL;

CREATE TABLE interventions (
    intervention_id text PRIMARY KEY,
    kind text NOT NULL,
    scope_kind text NOT NULL,
    scope_ref text NOT NULL,
    applied_at timestamptz NOT NULL,
    params jsonb NOT NULL DEFAULT '{}'::jsonb,
    hypothesis text,
    taxonomy_version text NOT NULL
);

CREATE TABLE intervention_effects (
    intervention_id text NOT NULL REFERENCES interventions (intervention_id),
    metric text NOT NULL,
    baseline_from timestamptz NOT NULL,
    baseline_to timestamptz NOT NULL,
    post_from timestamptz NOT NULL,
    post_to timestamptz NOT NULL,
    baseline_value numeric(18,6),
    post_value numeric(18,6),
    baseline_n int,
    post_n int,
    method text NOT NULL,
    task_mix_adjusted boolean NOT NULL DEFAULT false,
    causality_level text NOT NULL DEFAULT 'association',
    control_value numeric(18,6),
    control_n int,
    effect_estimate numeric(18,6),
    ci_low numeric(18,6),
    ci_high numeric(18,6),
    computed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (intervention_id, metric, post_to)
);

CREATE TABLE metric_definitions (
    metric text PRIMARY KEY,
    version text NOT NULL,
    formula text NOT NULL,
    unit text NOT NULL,
    granularity text NOT NULL,
    cohort_floor_applies boolean NOT NULL DEFAULT true
);

INSERT INTO metric_definitions (metric, version, formula, unit, granularity, cohort_floor_applies) VALUES
    ('llm_requests', '2.0.0', 'count(distinct transaction_id)', 'count', 'task', true),
    ('input_tokens', '2.0.0', 'sum(input_tokens)', 'tokens', 'task', true),
    ('output_tokens', '2.0.0', 'sum(output_tokens)', 'tokens', 'task', true),
    ('cache_read_tokens', '2.0.0', 'sum(cache_read_tokens)', 'tokens', 'task', true),
    ('cost_usd_metered', '2.0.0', 'sum(cost_usd) where cost_source <> ''none'' and billing_mode = ''metered''', 'usd', 'task', true),
    ('cost_usd_notional', '2.0.0', 'sum(cost_usd) where billing_mode = ''subscription''', 'usd', 'task', true),
    ('cost_per_completed_task', '2.0.0', 'sum(cost_usd) where billing_mode = ''metered'' divided by count(tasks with artifact_class in (merged_pr, committed_patch))', 'usd', 'policy', true),
    ('notional_cost_per_completed_task', '2.0.0', 'sum(cost_usd) where billing_mode = ''subscription'' divided by count(tasks with artifact_class in (merged_pr, committed_patch))', 'usd', 'policy', true),
    ('fallback_rate', '2.0.0', 'count(attempts with fallback_step > 1) / count(attempts)', 'ratio', 'policy', true),
    ('repair_loops', '2.0.0', 'count(distinct retry_family_id)', 'count', 'task', true),
    ('futile_retry_rate', '2.0.0', '1 - count(distinct context_fingerprint) / count(attempts) within retry_family', 'ratio', 'session', true),
    ('context_breadth_files', '2.0.0', 'count(distinct file referenced in context of attempt)', 'files', 'attempt', true),
    ('stage_conversion', '2.0.0', 'count(tasks reaching stage s+1) / count(tasks reaching stage s)', 'ratio', 'cohort', true),
    ('abandonment_rate', '2.0.0', 'count(tasks with linkage_state = timed_out) / count(tasks)', 'ratio', 'cohort', true),
    ('wall_duration', '2.0.0', 'max(response_ts) - min(request_ts)', 'interval', 'task', true),
    ('task_type_labeled_rate', '2.0.0', 'count(tasks with task_type not null) / count(tasks)', 'ratio', 'cohort', true),
    ('run_settlement_rate', '2.0.0', 'count(runs with settled_at not null) / count(runs)', 'ratio', 'session', true),
    ('fallback_observed_rate', '2.0.0', 'count(attempts with len(observed_fallback_chain) > 0) / count(attempts)', 'ratio', 'policy', true);

CREATE TABLE retention_policies (
    table_name text PRIMARY KEY,
    retention_days int NOT NULL,
    enabled boolean NOT NULL DEFAULT true,
    updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO retention_policies (table_name, retention_days) VALUES
    ('raw_events', 90),
    ('runtime_transactions', 730),
    ('actions', 180),
    ('artifacts', 1825),
    ('clock_observations', 30);

CREATE TABLE integration_sources (
    source_id text PRIMARY KEY,
    kind text NOT NULL,
    endpoint text,
    auth_ref text,
    capabilities jsonb NOT NULL DEFAULT '{}'::jsonb,
    registered_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE redaction_rules (
    rule_id text PRIMARY KEY,
    version text NOT NULL,
    category text NOT NULL,
    pattern_kind text NOT NULL,
    enabled boolean NOT NULL DEFAULT true
);

CREATE VIEW artifact_refs AS
SELECT
    a.artifact_id,
    a.kind,
    a.artifact_class,
    a.external_url,
    CASE
        WHEN a.kind = 'commit' THEN COALESCE(a.repo_remote, 'repo') || '@' || COALESCE(a.commit_sha, 'unknown')
        WHEN a.kind = 'pr' THEN COALESCE(a.repo_remote, 'repo') || '#pr-' || COALESCE(a.pr_number::text, 'unknown')
        WHEN a.kind = 'ci_run' THEN 'ci:' || COALESCE(a.ci_run_id, 'unknown')
        WHEN a.kind = 'file_set' THEN 'files:' || COALESCE(jsonb_array_length(a.files)::text, '0')
        ELSE a.artifact_id
    END AS ref
FROM artifacts a;

CREATE VIEW task_artifact_summary AS
WITH base AS (
    SELECT
        ta.task_id,
        ta.artifact_id,
        ta.state,
        ta.is_primary,
        ta.linked_at,
        r.ref,
        r.kind,
        r.artifact_class,
        cr.rank
    FROM task_artifacts ta
    JOIN artifact_refs r ON r.artifact_id = ta.artifact_id
    LEFT JOIN artifact_class_rank cr ON cr.artifact_class = r.artifact_class
), agg AS (
    SELECT
        b.task_id,
        count(*) AS artifacts_count,
        count(*) FILTER (WHERE b.state = 'confirmed') AS confirmed_count,
        count(*) FILTER (WHERE b.state = 'candidate') AS candidate_count,
        count(*) FILTER (WHERE b.state IN ('candidate', 'confirmed')) AS active_count,
        jsonb_agg(DISTINCT b.ref) FILTER (WHERE b.state IN ('candidate', 'confirmed')) AS artifact_refs,
        jsonb_agg(DISTINCT b.ref) AS all_artifact_refs,
        jsonb_agg(DISTINCT b.kind) FILTER (WHERE b.state IN ('candidate', 'confirmed')) AS artifact_kinds,
        max(b.rank) FILTER (WHERE b.state = 'confirmed') AS best_rank
    FROM base b
    GROUP BY b.task_id
)
SELECT
    agg.task_id,
    agg.artifacts_count,
    agg.confirmed_count,
    agg.candidate_count,
    agg.active_count,
    COALESCE(agg.artifact_refs, '[]'::jsonb) AS artifact_refs,
    COALESCE(agg.all_artifact_refs, '[]'::jsonb) AS all_artifact_refs,
    COALESCE(agg.artifact_kinds, '[]'::jsonb) AS artifact_kinds,
    COALESCE(cr.artifact_class, 'none') AS artifact_class,
    (
        SELECT b.ref
        FROM base b
        WHERE b.task_id = agg.task_id AND b.state = 'confirmed'
        ORDER BY b.rank DESC NULLS LAST, b.is_primary DESC, b.linked_at ASC
        LIMIT 1
    ) AS primary_ref,
    (SELECT count(DISTINCT s.session_id) FROM task_sessions s WHERE s.task_id = agg.task_id) AS sessions_count,
    (SELECT count(DISTINCT s.session_id) FROM task_sessions s WHERE s.task_id = agg.task_id) > 1 AS crosses_sessions
FROM agg
LEFT JOIN artifact_class_rank cr ON cr.rank = agg.best_rank;

CREATE VIEW task_outcome_resolved AS
SELECT
    t.task_id,
    CASE WHEN COALESCE(s.confirmed_count, 0) > 0 THEN s.artifact_class ELSE COALESCE(o.artifact_class, 'none') END AS artifact_class,
    CASE WHEN COALESCE(s.confirmed_count, 0) > 0 THEN 'artifacts' ELSE 'decision' END AS class_source,
    o.human_verdict,
    o.linkage_state,
    o.decided_at,
    COALESCE(s.artifacts_count, 0) AS artifacts_count,
    COALESCE(s.crosses_sessions, false) AS crosses_sessions,
    s.primary_ref,
    COALESCE(s.artifact_refs, '[]'::jsonb) AS artifact_refs
FROM tasks t
LEFT JOIN task_artifact_summary s ON s.task_id = t.task_id
LEFT JOIN task_outcomes o ON o.task_id = t.task_id AND o.superseded_by IS NULL;

CREATE VIEW transactions_outcome_links AS
SELECT
    rt.transaction_id,
    rt.task_id,
    s.primary_ref AS outcome_link,
    COALESCE(s.artifact_refs, '[]'::jsonb) AS outcome_links,
    COALESCE(jsonb_array_length(s.artifact_refs), 0) AS outcome_link_count,
    COALESCE(s.artifact_kinds, '[]'::jsonb) AS artifact_kinds
FROM runtime_transactions rt
LEFT JOIN task_artifact_summary s ON s.task_id = rt.task_id
WHERE rt.superseded_by IS NULL;

CREATE VIEW transactions_19 AS
SELECT
    t.session_id,
    t.developer_id,
    t.agent_tool,
    t.task_id,
    ta.task_type,
    ta.project_id AS project,
    t.auth_mode,
    t.policy_id,
    t.requested_model,
    t.resolved_model,
    COALESCE(t.observed_fallback_chain, '[]'::jsonb) AS fallback_chain,
    t.request_ts,
    t.input_tokens,
    t.output_tokens,
    t.status,
    (t.attempt_ordinal - 1) AS retry_index,
    t.stage || '/' || t.action_type AS stage_action_type,
    t.cost_usd,
    r.primary_ref AS outcome_link,
    r.artifact_class AS outcome_type
FROM runtime_transactions t
LEFT JOIN tasks ta ON ta.task_id = t.task_id
LEFT JOIN task_outcome_resolved r ON r.task_id = t.task_id
WHERE t.superseded_by IS NULL;

CREATE VIEW policy_fallback_context AS
SELECT
    t.transaction_id,
    t.policy_id,
    t.policy_version,
    t.fallback_step,
    t.observed_fallback_chain,
    prefix.chain AS configured_chain_prefix,
    p.configured_chain
FROM runtime_transactions t
LEFT JOIN policies p
    ON p.policy_id = t.policy_id AND p.policy_version = t.policy_version
LEFT JOIN LATERAL (
    SELECT jsonb_agg(x.elem ORDER BY x.ord) AS chain
    FROM jsonb_array_elements_text(COALESCE(p.configured_chain, '[]'::jsonb)) WITH ORDINALITY AS x(elem, ord)
    WHERE x.ord <= COALESCE(t.fallback_step, 1)
) prefix ON true
WHERE t.superseded_by IS NULL;

CREATE MATERIALIZED VIEW task_metrics AS
SELECT
    ta.task_id,
    count(rt.transaction_id) AS llm_requests,
    COALESCE(sum(rt.input_tokens), 0) AS input_tokens,
    COALESCE(sum(rt.output_tokens), 0) AS output_tokens,
    COALESCE(sum(rt.cache_read_tokens), 0) AS cache_read_tokens,
    COALESCE(sum(rt.cost_usd) FILTER (WHERE rt.billing_mode = 'metered'), 0) AS cost_usd_metered,
    COALESCE(sum(rt.cost_usd) FILTER (WHERE rt.billing_mode = 'subscription'), 0) AS cost_usd_notional,
    count(DISTINCT rt.retry_family_id) AS repair_loops,
    count(rt.transaction_id) FILTER (WHERE rt.status = 'rate_limited') AS rate_limited_requests,
    max(rt.response_ts) - min(rt.request_ts) AS wall_duration,
    max(r.artifact_class) AS artifact_class,
    max(r.class_source) AS class_source,
    max(r.human_verdict) AS human_verdict,
    max(r.linkage_state) AS linkage_state,
    max(r.artifacts_count) AS artifacts_count
FROM tasks ta
LEFT JOIN runtime_transactions rt
    ON rt.task_id = ta.task_id AND rt.superseded_by IS NULL
LEFT JOIN task_outcome_resolved r
    ON r.task_id = ta.task_id
GROUP BY ta.task_id;

CREATE UNIQUE INDEX task_metrics_task ON task_metrics (task_id);

CREATE VIEW policy_comparison AS
SELECT
    ta.policy_id,
    ta.policy_version,
    count(*) AS tasks,
    count(*) FILTER (WHERE m.artifact_class IN ('merged_pr', 'committed_patch')) AS tasks_completed,
    COALESCE(sum(m.cost_usd_metered), 0) AS cost_usd_metered,
    COALESCE(sum(m.cost_usd_metered) FILTER (WHERE m.artifact_class IN ('merged_pr', 'committed_patch')), 0) AS cost_usd_completed,
    COALESCE(avg(m.cost_usd_metered) FILTER (WHERE m.artifact_class IN ('merged_pr', 'committed_patch')), 0) AS cost_per_completed_task,
    COALESCE(sum(m.cost_usd_notional) FILTER (WHERE m.artifact_class IN ('merged_pr', 'committed_patch')), 0) AS notional_cost_usd_completed,
    COALESCE(avg(m.cost_usd_notional) FILTER (WHERE m.artifact_class IN ('merged_pr', 'committed_patch')), 0) AS notional_cost_per_completed_task,
    COALESCE(avg(m.repair_loops), 0) AS repair_loops_per_task
FROM tasks ta
JOIN task_metrics m ON m.task_id = ta.task_id
WHERE ta.policy_id IS NOT NULL
GROUP BY ta.policy_id, ta.policy_version;

CREATE VIEW fallback_rate_by_policy AS
SELECT
    rt.policy_id,
    rt.policy_version,
    count(*) AS attempts,
    count(*) FILTER (WHERE COALESCE(rt.fallback_step, 1) > 1) AS fallback_attempts,
    count(*) FILTER (WHERE COALESCE(rt.fallback_step, 1) > 1)::numeric / NULLIF(count(*), 0) AS fallback_rate
FROM runtime_transactions rt
WHERE rt.superseded_by IS NULL AND rt.policy_id IS NOT NULL
GROUP BY rt.policy_id, rt.policy_version;

CREATE VIEW stage_funnel AS
SELECT
    a.task_id,
    a.stage,
    count(*) AS actions,
    count(DISTINCT a.turn_id) AS turns,
    count(*) FILTER (WHERE a.is_error) AS errors
FROM actions a
GROUP BY a.task_id, a.stage;

CREATE VIEW stage_conversion AS
WITH stage_order (stage, ord) AS (
    VALUES ('frame', 1), ('locate', 2), ('plan', 3), ('edit', 4), ('verify', 5), ('repair', 6), ('review', 7), ('deliver', 8)
), per_task_stage AS (
    SELECT DISTINCT a.task_id, so.ord
    FROM actions a
    JOIN stage_order so ON so.stage = a.stage
    WHERE a.task_id IS NOT NULL
)
SELECT
    so.stage AS from_stage,
    nxt.stage AS to_stage,
    count(cur.task_id) AS tasks_reached,
    count(nxt_task.task_id) AS tasks_converted,
    count(nxt_task.task_id)::numeric / NULLIF(count(cur.task_id), 0) AS conversion
FROM stage_order so
LEFT JOIN stage_order nxt ON nxt.ord = so.ord + 1
LEFT JOIN per_task_stage cur ON cur.ord = so.ord
LEFT JOIN per_task_stage nxt_task ON nxt_task.task_id = cur.task_id AND nxt_task.ord = so.ord + 1
GROUP BY so.ord, so.stage, nxt.stage
ORDER BY so.ord;

CREATE VIEW turn_paths AS
SELECT
    a.turn_id,
    a.task_id,
    string_agg(a.stage, '>' ORDER BY a.action_seq) AS path,
    bool_or(a.stage = 'repair') AS has_repair,
    bool_or(COALESCE(a.is_error, false)) AS has_error,
    bool_or(a.semantic_action = 'test') AS has_test
FROM actions a
WHERE a.turn_id IS NOT NULL
GROUP BY a.turn_id, a.task_id;

CREATE VIEW futile_retries AS
SELECT
    rt.retry_family_id,
    rt.task_id,
    count(*) AS attempts,
    count(DISTINCT rt.context_fingerprint) AS distinct_contexts,
    count(*) - count(DISTINCT rt.context_fingerprint) AS futile_attempts
FROM runtime_transactions rt
WHERE rt.retry_family_id IS NOT NULL AND rt.superseded_by IS NULL
GROUP BY rt.retry_family_id, rt.task_id;

CREATE VIEW developer_cohorts AS
SELECT
    ta.developer_id,
    ta.task_type,
    count(*) AS tasks,
    count(*) FILTER (WHERE m.artifact_class IN ('merged_pr', 'committed_patch')) AS tasks_completed,
    count(*) FILTER (WHERE m.artifact_class IN ('merged_pr', 'committed_patch'))::numeric / NULLIF(count(*), 0) AS completed_rate,
    COALESCE(avg(m.llm_requests), 0) AS avg_requests,
    COALESCE(avg(m.repair_loops), 0) AS avg_repair_loops,
    COALESCE(avg(m.cost_usd_metered), 0) AS avg_cost_usd,
    count(*) FILTER (WHERE m.linkage_state = 'timed_out')::numeric / NULLIF(count(*), 0) AS abandonment_rate
FROM tasks ta
JOIN task_metrics m ON m.task_id = ta.task_id
WHERE ta.task_type IS NOT NULL
GROUP BY ta.developer_id, ta.task_type
HAVING count(*) >= (SELECT value::int FROM settings WHERE key = 'min_cohort_size');

CREATE VIEW developer_peer_baseline AS
SELECT
    c.developer_id,
    c.task_type,
    c.tasks,
    c.completed_rate,
    avg(c.completed_rate) OVER (PARTITION BY c.task_type) AS task_type_completed_rate,
    c.completed_rate - avg(c.completed_rate) OVER (PARTITION BY c.task_type) AS delta_vs_peers,
    avg(c.avg_repair_loops) OVER (PARTITION BY c.task_type) AS task_type_avg_repair_loops,
    c.avg_repair_loops - avg(c.avg_repair_loops) OVER (PARTITION BY c.task_type) AS repair_loop_delta_vs_peers,
    count(*) OVER (PARTITION BY c.task_type) AS peer_cohorts
FROM developer_cohorts c;

CREATE VIEW task_type_coverage AS
SELECT
    ta.developer_id,
    count(*) AS tasks,
    count(*) FILTER (WHERE ta.task_type IS NOT NULL) AS tasks_labeled,
    count(*) FILTER (WHERE ta.task_type IS NOT NULL)::numeric / NULLIF(count(*), 0) AS labeled_rate,
    count(*) FILTER (WHERE ta.task_type_source = 'inferred') AS tasks_inferred
FROM tasks ta
GROUP BY ta.developer_id;

CREATE VIEW run_settlement AS
SELECT
    r.session_id,
    r.run_id,
    r.started_at,
    r.settled_at,
    r.outcome,
    r.boundary_event,
    r.settled_at IS NOT NULL AS is_settled,
    count(rt.transaction_id) AS transactions
FROM runs r
LEFT JOIN runtime_transactions rt ON rt.run_id = r.run_id AND rt.superseded_by IS NULL
GROUP BY r.session_id, r.run_id, r.started_at, r.settled_at, r.outcome, r.boundary_event;

CREATE VIEW capture_quality AS
SELECT
    s.agent_tool,
    s.id_source,
    rt.source_primary,
    rt.linkage_state,
    count(*) AS transactions,
    COALESCE(avg(rt.match_confidence), 0) AS avg_match_confidence
FROM runtime_transactions rt
JOIN sessions s ON s.session_id = rt.session_id
WHERE rt.superseded_by IS NULL
GROUP BY s.agent_tool, s.id_source, rt.source_primary, rt.linkage_state;

CREATE VIEW model_divergences AS
SELECT
    rt.session_id,
    rt.task_id,
    rt.request_ts,
    rt.virtual_model,
    rt.requested_model,
    rt.resolved_model_transcript,
    rt.resolved_model_gateway,
    (SELECT count(DISTINCT m) FROM unnest(ARRAY[rt.requested_model, rt.resolved_model_transcript, rt.resolved_model_gateway]) AS m WHERE m IS NOT NULL) AS distinct_models,
    rt.policy_id,
    rt.policy_version
FROM runtime_transactions rt
WHERE rt.model_divergence IS TRUE AND rt.superseded_by IS NULL;

CREATE FUNCTION require_outcome_at_close() RETURNS trigger AS $$
BEGIN
    IF NEW.closed_at IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.closed_at IS DISTINCT FROM NEW.closed_at) THEN
        IF NOT EXISTS (
            SELECT 1 FROM task_outcomes o
            WHERE o.task_id = NEW.task_id AND o.superseded_by IS NULL
        ) THEN
            RAISE EXCEPTION 'task % closed without outcome', NEW.task_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER tasks_require_outcome
AFTER INSERT OR UPDATE ON tasks
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION require_outcome_at_close();

CREATE FUNCTION enforce_superseded_immutable() RETURNS trigger AS $$
BEGIN
    IF OLD.superseded_by IS NOT NULL THEN
        RAISE EXCEPTION 'row % is superseded and immutable', OLD.transaction_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER runtime_transactions_superseded_immutable
BEFORE UPDATE ON runtime_transactions
FOR EACH ROW EXECUTE FUNCTION enforce_superseded_immutable();
