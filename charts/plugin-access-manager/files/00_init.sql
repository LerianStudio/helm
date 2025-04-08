-- Create the sequence used for the primary key
CREATE SEQUENCE IF NOT EXISTS "lerian_user_enforcer_casbin_rule_id_seq";

-- Create the table used by casbin to enforce permissions
CREATE TABLE IF NOT EXISTS "lerian_user_enforcer_casbin_rule" (
    "id" BIGINT PRIMARY KEY DEFAULT nextval('lerian_user_enforcer_casbin_rule_id_seq'),
    "ptype" CHARACTER VARYING(100),
    "v0" CHARACTER VARYING(100),
    "v1" CHARACTER VARYING(100),
    "v2" CHARACTER VARYING(100),
    "v3" CHARACTER VARYING(100),
    "v4" CHARACTER VARYING(100),
    "v5" CHARACTER VARYING(100)
);

-- Create indexes for the table
CREATE INDEX IF NOT EXISTS idx_ptype ON "lerian_user_enforcer_casbin_rule" ("ptype");
CREATE INDEX IF NOT EXISTS idx_v0 ON "lerian_user_enforcer_casbin_rule" ("v0");
CREATE INDEX IF NOT EXISTS idx_v1 ON "lerian_user_enforcer_casbin_rule" ("v1");
CREATE INDEX IF NOT EXISTS idx_v2 ON "lerian_user_enforcer_casbin_rule" ("v2");
CREATE INDEX IF NOT EXISTS idx_v3 ON "lerian_user_enforcer_casbin_rule" ("v3");
CREATE INDEX IF NOT EXISTS idx_v4 ON "lerian_user_enforcer_casbin_rule" ("v4");
CREATE INDEX IF NOT EXISTS idx_v5 ON "lerian_user_enforcer_casbin_rule" ("v5");

-- Insert the default group and policy
INSERT INTO "lerian_user_enforcer_casbin_rule" ("ptype", "v0", "v1", "v2", "v3", "v4", "v5") VALUES
('p', 'lerian/identity-editor-role', 'applications',  'get', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'applications',  'post', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'applications',  'delete', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'groups',        'get', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'users',         'get', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'users',         'post', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'users',         'patch', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'users',         'delete', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'users/update-password','patch', 'allow', '', 'lerian/identity-editor-permission'),
('p', 'lerian/identity-editor-role', 'users/reset-password','patch', 'allow', '', 'lerian/identity-editor-permission'),

('p', 'lerian/user-default-role', 'users/update-password','patch', 'allow', '', 'lerian/identity-default-permission'),

('p', 'lerian/midaz-editor-role', 'accounts', 'delete', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'accounts', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'accounts', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'accounts', 'post', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'organizations', 'delete', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'organizations', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'organizations', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'organizations', 'post', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'ledgers', 'delete', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'ledgers', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'ledgers', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'ledgers', 'post', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'assets', 'delete', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'assets', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'assets', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'assets', 'post', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'asset-rates', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'asset-rates', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'asset-rates', 'put', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'portfolios', 'delete', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'portfolios', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'portfolios', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'portfolios', 'post', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'segments', 'delete', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'segments', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'segments', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'segments', 'post', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'balances', 'delete', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'balances', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'balances', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'transactions', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'transactions', 'post', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'transactions', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/midaz-editor-role', 'operations', 'get', 'allow', '', 'lerian/midaz-editor-permission'),
('p', 'lerian/midaz-editor-role', 'operations', 'patch', 'allow', '', 'lerian/midaz-editor-permission'),

('p', 'lerian/plugin-crm-editor-role', 'holders', 'delete', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'holders', 'get', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'holders', 'patch', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'holders', 'post', 'allow', '', 'lerian/plugin-crm-editor-permission'),

('p', 'lerian/plugin-crm-editor-role', 'accounts', 'delete', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'accounts', 'get', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'accounts', 'patch', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'accounts', 'post', 'allow', '', 'lerian/plugin-crm-editor-permission'),

('p', 'lerian/plugin-fees-editor-role', 'package', 'delete', 'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'package', 'get', 'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'package', 'patch', 'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'package', 'post', 'allow', '', 'lerian/plugin-fees-editor-permission'),

('p', 'lerian/plugin-fees-editor-role', 'fee', 'delete', 'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'fee', 'get', 'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'fee', 'patch', 'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'fee', 'post', 'allow', '', 'lerian/plugin-fees-editor-permission');

-- Create the sequence used for the primary key
CREATE SEQUENCE IF NOT EXISTS "lerian_m2m_enforcer_casbin_rule_id_seq";

-- Create the table used by casbin to enforce permissions
CREATE TABLE IF NOT EXISTS "lerian_m2m_enforcer_casbin_rule" (
    "id" BIGINT PRIMARY KEY DEFAULT nextval('lerian_m2m_enforcer_casbin_rule_id_seq'),
    "ptype" CHARACTER VARYING(100),
    "v0" CHARACTER VARYING(100),
    "v1" CHARACTER VARYING(100),
    "v2" CHARACTER VARYING(100),
    "v3" CHARACTER VARYING(100),
    "v4" CHARACTER VARYING(100),
    "v5" CHARACTER VARYING(100)
);