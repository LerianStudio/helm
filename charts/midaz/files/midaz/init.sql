-- The replication user is managed by the Bitnami PostgreSQL subchart via
-- auth.replicationUsername / auth.replicationPassword. Do NOT create it here:
-- a manual CREATE USER duplicates the chart-managed role, hardcodes a
-- credential in a plaintext ConfigMap, and diverges from the password the
-- standby actually authenticates with.

SELECT pg_create_physical_replication_slot('replication_slot');
SELECT * FROM pg_create_logical_replication_slot('logical_slot', 'pgoutput');

CREATE DATABASE onboarding;
CREATE DATABASE transaction;