-- pgTAP provides the assertion functions (plan, ok, is, throws_ok ...) used by
-- the SQL tests in supabase/tests/. It lives in its own schema so it never
-- mixes with application tables.
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
