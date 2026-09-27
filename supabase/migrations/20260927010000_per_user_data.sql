-- Per-user data: every row belongs to one auth user, and row-level security
-- lets each user see and change only their own rows.
--
-- BEFORE RUNNING
--   1. Create your own account first: Dashboard → Authentication → Users →
--      "Add user" (email + password, tick "Auto Confirm User").
--      Existing rows are assigned to the ONLY user in auth.users; the script
--      aborts if there are zero or several.
--   2. Run it together with installing the auth-enabled app build. After this,
--      the publishable key alone can no longer read or write anything, so the
--      current (pre-auth) app build will stop syncing. Its unsynced changes
--      stay queued on the device; they are not lost.
--
-- The whole script is one transaction: if any step fails, nothing changes.

begin;

-- ── 1. Owner column on every synced table ──────────────────────────────────
-- default auth.uid() stamps the signed-in user on insert, so the app never
-- has to send user_id itself (and can't spoof someone else's).
alter table public.categories         add column if not exists user_id uuid references auth.users (id) on delete cascade default auth.uid();
alter table public.transactions       add column if not exists user_id uuid references auth.users (id) on delete cascade default auth.uid();
alter table public.budgets            add column if not exists user_id uuid references auth.users (id) on delete cascade default auth.uid();
alter table public.recurring_expenses add column if not exists user_id uuid references auth.users (id) on delete cascade default auth.uid();

-- ── 2. Hand existing rows to the single existing account ────────────────────
do $$
declare
  n int;
  owner uuid;
begin
  select count(*) into n from auth.users;
  if n <> 1 then
    raise exception 'Expected exactly 1 user in auth.users to own existing data, found %. Create your account first (and only yours), then re-run.', n;
  end if;
  select id into owner from auth.users;

  update public.categories         set user_id = owner where user_id is null;
  update public.transactions       set user_id = owner where user_id is null;
  update public.budgets            set user_id = owner where user_id is null;
  update public.recurring_expenses set user_id = owner where user_id is null;
end $$;

alter table public.categories         alter column user_id set not null;
alter table public.transactions       alter column user_id set not null;
alter table public.budgets            alter column user_id set not null;
alter table public.recurring_expenses alter column user_id set not null;

create index if not exists categories_user_id_idx         on public.categories (user_id);
create index if not exists transactions_user_id_idx       on public.transactions (user_id);
create index if not exists budgets_user_id_idx            on public.budgets (user_id);
create index if not exists recurring_expenses_user_id_idx on public.recurring_expenses (user_id);

-- ── 3. Category names unique per user, not globally ─────────────────────────
-- Constraint/index names aren't known from here, so find whatever enforces
-- uniqueness on categories(name) alone and drop it.
do $$
declare
  r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    where con.conrelid = 'public.categories'::regclass
      and con.contype = 'u'
      and con.conkey = array[(select attnum from pg_attribute
                              where attrelid = 'public.categories'::regclass and attname = 'name')]
  loop
    execute format('alter table public.categories drop constraint %I', r.conname);
  end loop;

  for r in
    select i.indexrelid::regclass::text as idx
    from pg_index i
    where i.indrelid = 'public.categories'::regclass
      and i.indisunique and not i.indisprimary
      and i.indkey::int2[] = array[(select attnum from pg_attribute
                                    where attrelid = 'public.categories'::regclass and attname = 'name')]
      and not exists (select 1 from pg_constraint c where c.conindid = i.indexrelid)
  loop
    execute format('drop index %s', r.idx);
  end loop;
end $$;

alter table public.categories
  add constraint categories_user_id_name_key unique (user_id, name);

-- ── 4. Row-level security: owner-only access ────────────────────────────────
-- Drop every existing policy on these tables (the current ones let the
-- anonymous publishable key read and write everything).
do $$
declare
  r record;
begin
  for r in
    select tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('categories', 'transactions', 'budgets', 'recurring_expenses')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.categories         enable row level security;
alter table public.transactions       enable row level security;
alter table public.budgets            enable row level security;
alter table public.recurring_expenses enable row level security;

-- (select auth.uid()) is evaluated once per statement instead of per row.
create policy "owner can do everything" on public.categories
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "owner can do everything" on public.transactions
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "owner can do everything" on public.budgets
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "owner can do everything" on public.recurring_expenses
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Belt and braces: signed-out requests get no table access at all.
revoke all on public.categories, public.transactions, public.budgets, public.recurring_expenses from anon;
grant select, insert, update, delete
  on public.categories, public.transactions, public.budgets, public.recurring_expenses to authenticated;

-- ── 5. Starter categories for every new account ─────────────────────────────
-- Ids follow the app's scheme (epoch-ms × 1000 + n) so this doesn't depend on
-- the id column having a server-side default.
create or replace function public.seed_default_categories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint * 1000;
begin
  insert into public.categories (id, user_id, name, type, color, icon, created_at, updated_at)
  select base + d.ord, new.id, d.name, d.type, d.color, d.icon, now(), now()
  from (values
    ( 1, 'Groceries',     'expense', '#22c55e', 'cart'),
    ( 2, 'Dining Out',    'expense', '#f97316', 'utensils'),
    ( 3, 'Transport',     'expense', '#0ea5e9', 'car'),
    ( 4, 'Housing',       'expense', '#a855f7', 'home'),
    ( 5, 'Utilities',     'expense', '#eab308', 'bolt'),
    ( 6, 'Entertainment', 'expense', '#ec4899', 'film'),
    ( 7, 'Shopping',      'expense', '#ef4444', 'bag'),
    ( 8, 'Health',        'expense', '#14b8a6', 'heart'),
    ( 9, 'Subscriptions', 'expense', '#f59e0b', 'tag'),
    (10, 'Other Expense', 'expense', '#64748b', 'tag'),
    (11, 'Salary',        'income',  '#16a34a', 'banknote'),
    (12, 'Freelance',     'income',  '#0d9488', 'briefcase'),
    (13, 'Other Income',  'income',  '#475569', 'plus-circle')
  ) as d (ord, name, type, color, icon);
  return new;
end $$;

drop trigger if exists on_auth_user_created_seed_categories on auth.users;
create trigger on_auth_user_created_seed_categories
  after insert on auth.users
  for each row execute function public.seed_default_categories();

commit;

-- ── Rollback (manual; run only if you need to undo) ─────────────────────────
-- begin;
-- drop trigger if exists on_auth_user_created_seed_categories on auth.users;
-- drop function if exists public.seed_default_categories();
-- drop policy if exists "owner can do everything" on public.categories;
-- drop policy if exists "owner can do everything" on public.transactions;
-- drop policy if exists "owner can do everything" on public.budgets;
-- drop policy if exists "owner can do everything" on public.recurring_expenses;
-- alter table public.categories drop constraint if exists categories_user_id_name_key;
-- alter table public.categories add constraint categories_name_key unique (name);
-- alter table public.categories         drop column if exists user_id;
-- alter table public.transactions       drop column if exists user_id;
-- alter table public.budgets            drop column if exists user_id;
-- alter table public.recurring_expenses drop column if exists user_id;
-- grant select, insert, update, delete on public.categories, public.transactions, public.budgets, public.recurring_expenses to anon;
-- -- then recreate whatever anon policies you had before
-- commit;
