-- Smoke test: proves the test runner, the database and pgTAP are wired up.
begin;
select plan(2);

select has_extension('pgtap', 'pgTAP extension is installed');
select has_schema('public', 'public schema exists');

select * from finish();
rollback;
