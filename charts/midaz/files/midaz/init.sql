-- The replication user is managed by the Bitnami PostgreSQL subchart via
-- auth.replicationUsername / auth.replicationPassword. Do NOT create it here:
-- a manual CREATE USER duplicates the chart-managed role, hardcodes a
-- credential in a plaintext ConfigMap, and diverges from the password the
-- standby actually authenticates with.

SELECT pg_create_physical_replication_slot('replication_slot');
SELECT * FROM pg_create_logical_replication_slot('logical_slot', 'pgoutput');

CREATE DATABASE onboarding;
CREATE DATABASE transaction;

-- Tracer shares this cluster and the `midaz` role that owns the databases above
-- (its Deployment reads the same subchart Secret). Created unconditionally, and
-- not gated on tracer.enabled, because initdb scripts run exactly once: gating
-- would leave the database missing for anyone enabling tracer after install.
-- An unused empty database costs nothing.
CREATE DATABASE tracer;