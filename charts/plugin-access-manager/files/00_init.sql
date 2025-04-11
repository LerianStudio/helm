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

('p', 'lerian/midaz-contributor-role', 'accounts', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'accounts', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'accounts', 'post', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'organizations', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'organizations', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'organizations', 'post', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'ledgers', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'ledgers', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'ledgers', 'post', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'assets', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'assets', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'assets', 'post', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'asset-rates', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'asset-rates', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'asset-rates', 'put', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'portfolios', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'portfolios', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'portfolios', 'post', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'segments', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'segments', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'segments', 'post', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'balances', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'balances', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'transactions', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'transactions', 'post', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'transactions', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'operations', 'get', 'allow', '', 'lerian/midaz-contributor-permission'),
('p', 'lerian/midaz-contributor-role', 'operations', 'patch', 'allow', '', 'lerian/midaz-contributor-permission'),

('p', 'lerian/midaz-viewer-role', 'accounts', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'organizations', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'ledgers', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'assets', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'asset-rates', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'portfolios', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'segments', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'balances', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'transactions', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),
('p', 'lerian/midaz-viewer-role', 'operations', 'get', 'allow', '', 'lerian/midaz-viewer-permission'),

('p', 'lerian/plugin-identity-editor-role', 'applications',  'get', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'applications',  'post', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'applications',  'delete', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'groups',        'get', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'users',         'get', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'users',         'post', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'users',         'patch', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'users',         'delete', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'update-password','patch', 'allow', '', 'lerian/plugin-identity-editor-permission'),
('p', 'lerian/plugin-identity-editor-role', 'reset-password','patch', 'allow', '', 'lerian/plugin-identity-editor-permission'),

('p', 'lerian/plugin-crm-editor-role', 'holders', 'delete', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'holders', 'get', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'holders', 'patch', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'holders', 'post', 'allow', '', 'lerian/plugin-crm-editor-permission'),

('p', 'lerian/plugin-crm-contributor-role', 'holders', 'get', 'allow', '', 'lerian/plugin-crm-contributor-permission'),
('p', 'lerian/plugin-crm-contributor-role', 'holders', 'patch', 'allow', '', 'lerian/plugin-crm-contributor-permission'),
('p', 'lerian/plugin-crm-contributor-role', 'holders', 'post', 'allow', '', 'lerian/plugin-crm-contributor-permission'),

('p', 'lerian/plugin-crm-editor-role', 'aliases', 'delete', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'aliases', 'get', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'aliases', 'patch', 'allow', '', 'lerian/plugin-crm-editor-permission'),
('p', 'lerian/plugin-crm-editor-role', 'aliases', 'post', 'allow', '', 'lerian/plugin-crm-editor-permission'),

('p', 'lerian/plugin-crm-contributor-role', 'aliases', 'get', 'allow', '', 'lerian/plugin-crm-contributor-permission'),
('p', 'lerian/plugin-crm-contributor-role', 'aliases', 'patch', 'allow', '', 'lerian/plugin-crm-contributor-permission'),
('p', 'lerian/plugin-crm-contributor-role', 'aliases', 'post', 'allow', '', 'lerian/plugin-crm-contributor-permission'),

('p', 'lerian/plugin-crm-viewer-role', 'holders', 'get', 'allow', '', 'lerian/plugin-crm-viewer-permission'),
('p', 'lerian/plugin-crm-viewer-role', 'aliases', 'get', 'allow', '', 'lerian/plugin-crm-viewer-permission'),

('p', 'lerian/plugin-fees-editor-role', 'packages', 'delete', 'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'packages', 'get',    'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'packages', 'patch',  'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'packages', 'post',   'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'fees', 'get',   'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'fees', 'post',   'allow', '', 'lerian/plugin-fees-editor-permission'),
('p', 'lerian/plugin-fees-editor-role', 'estimates', 'post',   'allow', '', 'lerian/plugin-fees-editor-permission'),

('p', 'lerian/plugin-fees-contributor-role', 'packages', 'get',    'allow', '', 'lerian/plugin-fees-contributor-permission'),
('p', 'lerian/plugin-fees-contributor-role', 'packages', 'patch',  'allow', '', 'lerian/plugin-fees-contributor-permission'),
('p', 'lerian/plugin-fees-contributor-role', 'packages', 'post',   'allow', '', 'lerian/plugin-fees-contributor-permission'),
('p', 'lerian/plugin-fees-contributor-role', 'fees', 'get',   'allow', '', 'lerian/plugin-fees-contributor-permission'),
('p', 'lerian/plugin-fees-contributor-role', 'fees', 'post',   'allow', '', 'lerian/plugin-fees-contributor-permission'),
('p', 'lerian/plugin-fees-contributor-role', 'estimates', 'post',   'allow', '', 'lerian/plugin-fees-contributor-permission'),

('p', 'lerian/plugin-fees-viewer-role', 'packages', 'get',    'allow', '', 'lerian/plugin-fees-viewer-permission'),
('p', 'lerian/plugin-fees-viewer-role', 'fees', 'get',   'allow', '', 'lerian/plugin-fees-viewer-permission'),

('p', '*', 'update-password','patch', 'allow', '', 'lerian/plugin-identity-default-permission');

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