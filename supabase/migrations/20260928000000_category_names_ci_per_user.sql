-- Fix: new accounts can't be created ("Database error saving new user").
--
-- The original schema made category names case-insensitively unique with an
-- expression index, uq_categories_name_ci on lower(name). The per-user
-- migration only dropped plain indexes on the `name` column; an expression
-- index has indkey = 0, so this one survived and names stayed unique across
-- ALL accounts. Every signup then fails: the seed trigger inserts
-- "Groceries" etc. for the new user, collides with the existing owner's rows,
-- and rolls back the auth.users insert.
--
-- Keep the case-insensitive rule, but scope it to each user.

begin;

drop index if exists public.uq_categories_name_ci;

create unique index if not exists uq_categories_user_name_ci
  on public.categories (user_id, lower(name));

-- Subsumed by the case-insensitive index above.
alter table public.categories drop constraint if exists categories_user_id_name_key;

commit;

-- Verify (should list only the pkey and uq_categories_user_name_ci as unique):
-- select indexrelid::regclass, pg_get_indexdef(indexrelid)
-- from pg_index where indrelid = 'public.categories'::regclass and indisunique;

-- Rollback:
-- begin;
-- drop index if exists public.uq_categories_user_name_ci;
-- alter table public.categories add constraint categories_user_id_name_key unique (user_id, name);
-- commit;
