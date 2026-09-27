-- Already applied on 2026-09-27 via the SQL editor; recorded here for history.
-- Recurring items can be income as well as expenses.
alter table public.recurring_expenses
  add column if not exists type text not null default 'expense'
  check (type in ('income', 'expense'));
