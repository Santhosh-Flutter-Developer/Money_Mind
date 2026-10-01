-- =====================================================================
-- MoneyMind - Supabase schema, RLS policies and atomic RPC functions
-- Run this whole file once in the Supabase SQL editor.
-- All money columns are numeric(14,2). Every user-owned table has user_id
-- and Row Level Security: users can only touch rows where user_id = auth.uid().
-- =====================================================================
create extension if not exists "pgcrypto";

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;

-- ---------------------------------------------------------------- tables
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text not null default '',
  currency text not null default 'INR',
  salary_day int not null default 1 check (salary_day between 1 and 28),
  default_salary numeric(14,2) not null default 0 check (default_salary >= 0),
  cycle_mode text not null default 'salary_cycle' check (cycle_mode in ('salary_cycle','calendar_month')),
  avatar_url text,
  savings_goal numeric(14,2) check (savings_goal is null or savings_goal > 0),
  savings_goal_date date,
  onboarded boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  expense_reminders boolean not null default true,
  interest_reminders boolean not null default true,
  salary_reminder boolean not null default true,
  closing_reminder boolean not null default true,
  theme_mode text not null default 'system' check (theme_mode in ('system','light','dark')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  icon text not null default 'category',
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists categories_user_name_uq on public.categories(user_id, lower(name));

create table if not exists public.recurring_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null check (length(trim(name)) > 0),
  amount numeric(14,2) not null check (amount > 0),
  due_day int check (due_day between 1 and 31),
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists recurring_user_name_uq on public.recurring_expenses(user_id, lower(name));

create table if not exists public.monthly_budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  salary numeric(14,2) not null default 0 check (salary >= 0),
  status text not null default 'open' check (status in ('open','closed')),
  closed_at timestamptz,
  savings_transferred numeric(14,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (period_end >= period_start),
  unique (user_id, period_start)
);

create table if not exists public.budget_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  budget_id uuid not null references public.monthly_budgets(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  recurring_id uuid references public.recurring_expenses(id) on delete set null,
  name text not null check (length(trim(name)) > 0),
  amount numeric(14,2) not null check (amount > 0),
  due_date date,
  is_recurring boolean not null default false,
  status text not null default 'pending' check (status in ('pending','completed','skipped')),
  completed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists budget_items_recurring_uq on public.budget_items(budget_id, recurring_id) where recurring_id is not null;
create index if not exists budget_items_budget_idx on public.budget_items(budget_id);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('income','expense','lending','interest','savings','transfer')),
  direction text not null check (direction in ('in','out','neutral')),
  amount numeric(14,2) not null check (amount > 0),
  txn_date date not null default current_date,
  description text not null default '',
  category_id uuid references public.categories(id) on delete set null,
  budget_id uuid references public.monthly_budgets(id) on delete set null,
  ref_type text,
  ref_id uuid,
  created_at timestamptz not null default now()
);
create unique index if not exists transactions_ref_uq on public.transactions(ref_type, ref_id) where ref_id is not null;
create index if not exists transactions_user_date_idx on public.transactions(user_id, txn_date desc);

create table if not exists public.savings_wallet (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  balance numeric(14,2) not null default 0 check (balance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.savings_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  wallet_id uuid not null references public.savings_wallet(id) on delete cascade,
  type text not null check (type in ('monthly_savings','deposit','withdrawal','adjustment')),
  amount numeric(14,2) not null check (amount <> 0),
  txn_date date not null default current_date,
  description text not null default '',
  month_label text,
  budget_id uuid references public.monthly_budgets(id) on delete set null,
  notes text,
  idempotency_key uuid,
  created_at timestamptz not null default now()
);
create unique index if not exists savings_tx_key_uq on public.savings_transactions(user_id, idempotency_key) where idempotency_key is not null;
create unique index if not exists savings_tx_budget_uq on public.savings_transactions(budget_id) where type = 'monthly_savings';

create table if not exists public.loans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  person_name text not null check (length(trim(person_name)) > 0),
  phone text,
  principal numeric(14,2) not null check (principal > 0),
  rate numeric(7,3) not null check (rate >= 0),
  interest_type text not null default 'monthly_percentage' check (interest_type in ('monthly_percentage')),
  start_date date not null,
  expected_day int check (expected_day between 1 and 31),
  notes text,
  status text not null default 'active' check (status in ('active','closed')),
  principal_returned numeric(14,2) not null default 0,
  closed_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.loan_interest_periods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  loan_id uuid not null references public.loans(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  due_date date not null,
  expected_amount numeric(14,2) not null check (expected_amount >= 0),
  paid_amount numeric(14,2) not null default 0 check (paid_amount >= 0),
  remaining numeric(14,2) generated always as (expected_amount - paid_amount) stored,
  status text not null default 'pending' check (status in ('pending','partial','paid','overdue')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (loan_id, period_start)
);

create table if not exists public.loan_interest_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  loan_id uuid not null references public.loans(id) on delete cascade,
  period_id uuid not null references public.loan_interest_periods(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  payment_date date not null default current_date,
  notes text,
  idempotency_key uuid,
  created_at timestamptz not null default now()
);
create unique index if not exists interest_pay_key_uq on public.loan_interest_payments(user_id, idempotency_key) where idempotency_key is not null;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  kind text not null default 'general',
  scheduled_for timestamptz,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------- views
create or replace view public.budget_summaries with (security_invoker = true) as
select b.*,
  coalesce(i.planned, 0) as planned,
  coalesce(i.spent, 0) as spent,
  coalesce(i.pending, 0) as pending,
  coalesce(t.extra, 0) as extra_income
from public.monthly_budgets b
left join lateral (
  select sum(amount) filter (where status <> 'skipped') as planned,
         sum(amount) filter (where status = 'completed') as spent,
         sum(amount) filter (where status = 'pending') as pending
  from public.budget_items where budget_id = b.id) i on true
left join lateral (
  select sum(amount) as extra from public.transactions
  where budget_id = b.id and ref_type = 'other_income') t on true;

-- ------------------------------------------------- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array['profiles','app_settings','categories','recurring_expenses','monthly_budgets',
    'budget_items','savings_wallet','loans','loan_interest_periods'] loop
    execute format('drop trigger if exists trg_%1$s_updated on public.%1$s', t);
    execute format('create trigger trg_%1$s_updated before update on public.%1$s for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- RLS
do $$
declare t text;
begin
  foreach t in array array['app_settings','categories','recurring_expenses','monthly_budgets','budget_items',
    'transactions','savings_wallet','savings_transactions','loans','loan_interest_periods',
    'loan_interest_payments','notifications'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "own rows" on public.%I', t);
    execute format('create policy "own rows" on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
  end loop;
end $$;

alter table public.profiles enable row level security;
drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- ------------------------------------------ new-user bootstrap triggers
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', ''), coalesce(new.email, ''))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.init_user_data() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.savings_wallet(user_id) values (new.id) on conflict do nothing;
  insert into public.app_settings(user_id) values (new.id) on conflict do nothing;
  insert into public.categories(user_id, name, icon, is_default)
  select new.id, c.n, c.i, true from (values
    ('Food','restaurant'),('Groceries','shopping_basket'),('Gas','local_gas_station'),
    ('Electricity','bolt'),('Water','water_drop'),('Medicine','medication'),('Health','favorite'),
    ('Rent','home'),('Bike','two_wheeler'),('Car','directions_car'),('EMI','credit_card'),
    ('RD','savings'),('Investment','trending_up'),('Shopping','shopping_bag'),
    ('Entertainment','movie'),('Travel','flight'),('Bills','receipt_long'),
    ('Education','school'),('Family','family_restroom'),('Other','category')) as c(n, i)
  on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_profile_created on public.profiles;
create trigger on_profile_created after insert on public.profiles
for each row execute function public.init_user_data();

-- ------------------------------------------------ budget item guards
create or replace function public.guard_budget_items() returns trigger
language plpgsql set search_path = public as $$
declare v_status text; v_budget uuid;
begin
  v_budget := case when tg_op = 'DELETE' then old.budget_id else new.budget_id end;
  select status into v_status from public.monthly_budgets where id = v_budget;
  if v_status = 'closed' then raise exception 'ALREADY_CLOSED'; end if;
  if tg_op = 'UPDATE' and old.status = 'completed' and new.status = 'completed'
     and new.amount <> old.amount then
    raise exception 'COMPLETED_LOCKED';
  end if;
  if tg_op = 'DELETE' then
    delete from public.transactions where ref_type = 'budget_item' and ref_id = old.id;
    return old;
  end if;
  return new;
end $$;
drop trigger if exists trg_budget_items_guard on public.budget_items;
create trigger trg_budget_items_guard before insert or update or delete on public.budget_items
for each row execute function public.guard_budget_items();

-- ------------------------------------------------------- RPC helpers
create or replace function public.day_in_period(p_start date, p_end date, p_day int)
returns date language plpgsql immutable set search_path = public as $$
declare m date := date_trunc('month', p_start)::date; d date;
begin
  if p_day is null then return p_end; end if;
  d := m + (least(p_day, extract(day from (m + interval '1 month - 1 day'))::int) - 1);
  if d < p_start then
    m := (m + interval '1 month')::date;
    d := m + (least(p_day, extract(day from (m + interval '1 month - 1 day'))::int) - 1);
  end if;
  return d;
end $$;

-- Creates the budget for a cycle (idempotent) and copies active recurring expenses.
create or replace function public.ensure_budget(p_start date, p_end date, p_salary numeric default null)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_b public.monthly_budgets; v_salary numeric;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_b from public.monthly_budgets where user_id = v_uid and period_start = p_start;
  if found then return to_jsonb(v_b); end if;

  select coalesce(p_salary, default_salary) into v_salary from public.profiles where id = v_uid;
  insert into public.monthly_budgets(user_id, period_start, period_end, salary)
  values (v_uid, p_start, p_end, coalesce(v_salary, 0))
  on conflict (user_id, period_start) do nothing
  returning * into v_b;

  if v_b.id is null then  -- created concurrently by another call
    select * into v_b from public.monthly_budgets where user_id = v_uid and period_start = p_start;
    return to_jsonb(v_b);
  end if;

  insert into public.budget_items(user_id, budget_id, category_id, recurring_id, name, amount, due_date, is_recurring, notes)
  select v_uid, v_b.id, r.category_id, r.id, r.name, r.amount,
         public.day_in_period(p_start, p_end, r.due_day), true, r.notes
  from public.recurring_expenses r where r.user_id = v_uid and r.is_active
  on conflict do nothing;

  if v_b.salary > 0 then
    insert into public.transactions(user_id, type, direction, amount, txn_date, description, budget_id, ref_type, ref_id)
    values (v_uid, 'income', 'in', v_b.salary, p_start, 'Salary', v_b.id, 'salary', v_b.id)
    on conflict do nothing;
  end if;
  return to_jsonb(v_b);
end $$;

create or replace function public.update_budget_salary(p_budget_id uuid, p_salary numeric)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_b public.monthly_budgets;
begin
  if p_salary is null or p_salary < 0 then raise exception 'INVALID_AMOUNT'; end if;
  select * into v_b from public.monthly_budgets where id = p_budget_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_b.status = 'closed' then raise exception 'ALREADY_CLOSED'; end if;
  update public.monthly_budgets set salary = p_salary where id = v_b.id returning * into v_b;
  delete from public.transactions where user_id = v_uid and ref_type = 'salary' and ref_id = v_b.id;
  if p_salary > 0 then
    insert into public.transactions(user_id, type, direction, amount, txn_date, description, budget_id, ref_type, ref_id)
    values (v_uid, 'income', 'in', p_salary, v_b.period_start, 'Salary', v_b.id, 'salary', v_b.id);
  end if;
  return to_jsonb(v_b);
end $$;

-- Only COMPLETED items reduce the budget. Row lock + status check => double-tap safe.
create or replace function public.complete_budget_item(p_item_id uuid)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_i public.budget_items; v_status text;
begin
  select * into v_i from public.budget_items where id = p_item_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  select status into v_status from public.monthly_budgets where id = v_i.budget_id;
  if v_status = 'closed' then raise exception 'ALREADY_CLOSED'; end if;
  if v_i.status = 'completed' then return to_jsonb(v_i); end if;   -- already done: never deduct twice
  update public.budget_items set status = 'completed', completed_at = now()
  where id = v_i.id returning * into v_i;
  insert into public.transactions(user_id, type, direction, amount, txn_date, description, category_id, budget_id, ref_type, ref_id)
  values (v_uid, 'expense', 'out', v_i.amount, current_date, v_i.name, v_i.category_id, v_i.budget_id, 'budget_item', v_i.id)
  on conflict do nothing;
  return to_jsonb(v_i);
end $$;

create or replace function public.undo_budget_item(p_item_id uuid)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_i public.budget_items; v_status text;
begin
  select * into v_i from public.budget_items where id = p_item_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  select status into v_status from public.monthly_budgets where id = v_i.budget_id;
  if v_status = 'closed' then raise exception 'ALREADY_CLOSED'; end if;
  if v_i.status <> 'completed' then return to_jsonb(v_i); end if;
  update public.budget_items set status = 'pending', completed_at = null
  where id = v_i.id returning * into v_i;
  delete from public.transactions where ref_type = 'budget_item' and ref_id = v_i.id;
  return to_jsonb(v_i);
end $$;

-- Closes a cycle once, moving the remaining amount into the savings wallet.
create or replace function public.close_budget(p_budget_id uuid)
returns jsonb language plpgsql set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_b public.monthly_budgets; v_w public.savings_wallet;
  v_extra numeric; v_spent numeric; v_rem numeric; v_st uuid;
begin
  select * into v_b from public.monthly_budgets where id = p_budget_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_b.status = 'closed' then raise exception 'ALREADY_CLOSED'; end if;

  select coalesce(sum(amount), 0) into v_extra from public.transactions
   where budget_id = v_b.id and ref_type = 'other_income' and user_id = v_uid;
  select coalesce(sum(amount), 0) into v_spent from public.budget_items
   where budget_id = v_b.id and status = 'completed';
  v_rem := v_b.salary + v_extra - v_spent;

  if v_rem > 0 then
    select * into v_w from public.savings_wallet where user_id = v_uid for update;
    insert into public.savings_transactions(user_id, wallet_id, type, amount, txn_date, description, month_label, budget_id)
    values (v_uid, v_w.id, 'monthly_savings', v_rem, current_date,
            to_char(v_b.period_start, 'FMMonth YYYY') || ' savings', to_char(v_b.period_start, 'YYYY-MM'), v_b.id)
    returning id into v_st;
    update public.savings_wallet set balance = balance + v_rem where id = v_w.id;
    insert into public.transactions(user_id, type, direction, amount, txn_date, description, budget_id, ref_type, ref_id)
    values (v_uid, 'transfer', 'neutral', v_rem, current_date, 'Savings transfer', v_b.id, 'savings_txn', v_st);
  else
    v_rem := 0;
  end if;

  update public.monthly_budgets set status = 'closed', closed_at = now(), savings_transferred = v_rem
  where id = v_b.id returning * into v_b;
  return to_jsonb(v_b);
end $$;

-- Deposit / withdrawal / adjustment on the savings wallet (idempotent per key).
create or replace function public.savings_operation(
  p_type text, p_amount numeric, p_date date, p_description text, p_notes text, p_key uuid)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_w public.savings_wallet; v_delta numeric; v_id uuid;
begin
  if p_type not in ('deposit','withdrawal','adjustment') then raise exception 'INVALID_AMOUNT'; end if;
  if p_amount is null or p_amount = 0 or (p_type <> 'adjustment' and p_amount < 0) then
    raise exception 'INVALID_AMOUNT';
  end if;
  select * into v_w from public.savings_wallet where user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if p_key is not null and exists (select 1 from public.savings_transactions
      where user_id = v_uid and idempotency_key = p_key) then
    return jsonb_build_object('duplicate', true, 'balance', v_w.balance);
  end if;
  v_delta := case when p_type = 'withdrawal' then -p_amount else p_amount end;
  if v_w.balance + v_delta < 0 then raise exception 'INSUFFICIENT_BALANCE'; end if;
  insert into public.savings_transactions(user_id, wallet_id, type, amount, txn_date, description, month_label, notes, idempotency_key)
  values (v_uid, v_w.id, p_type, p_amount, coalesce(p_date, current_date),
          coalesce(nullif(p_description, ''), initcap(p_type)),
          to_char(coalesce(p_date, current_date), 'YYYY-MM'), p_notes, p_key)
  returning id into v_id;
  update public.savings_wallet set balance = balance + v_delta where id = v_w.id;
  insert into public.transactions(user_id, type, direction, amount, txn_date, description, ref_type, ref_id)
  values (v_uid, 'savings', 'neutral', abs(p_amount), coalesce(p_date, current_date),
          coalesce(nullif(p_description, ''), initcap(p_type)), 'savings_txn', v_id);
  return jsonb_build_object('id', v_id, 'balance', v_w.balance + v_delta);
end $$;

-- ------------------------------------------------------------- lending
create or replace function public.generate_interest_periods(p_loan_id uuid)
returns void language plpgsql set search_path = public as $$
declare v_l public.loans; k int := 0; v_s date; v_e date; v_last date;
begin
  select * into v_l from public.loans where id = p_loan_id and user_id = auth.uid();
  if not found then raise exception 'NOT_FOUND'; end if;
  v_last := case when v_l.status = 'closed' then coalesce(v_l.closed_on, current_date) else current_date end;
  loop
    v_s := (v_l.start_date + make_interval(months => k))::date;
    exit when v_s > v_last or k > 600;
    v_e := (v_l.start_date + make_interval(months => k + 1))::date - 1;
    insert into public.loan_interest_periods(user_id, loan_id, period_start, period_end, due_date, expected_amount)
    values (v_l.user_id, v_l.id, v_s, v_e, public.day_in_period(v_s, v_e, v_l.expected_day),
            round(v_l.principal * v_l.rate / 100, 2))
    on conflict (loan_id, period_start) do nothing;
    k := k + 1;
  end loop;
end $$;

create or replace function public.refresh_interest_periods()
returns void language plpgsql set search_path = public as $$
declare r record;
begin
  for r in select id from public.loans where user_id = auth.uid() and status = 'active' loop
    perform public.generate_interest_periods(r.id);
  end loop;
end $$;

create or replace function public.create_loan(
  p_name text, p_phone text, p_principal numeric, p_rate numeric, p_type text,
  p_start date, p_expected_day int, p_notes text)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_l public.loans;
begin
  insert into public.loans(user_id, person_name, phone, principal, rate, interest_type, start_date, expected_day, notes)
  values (v_uid, trim(p_name), nullif(p_phone, ''), p_principal, p_rate,
          coalesce(p_type, 'monthly_percentage'), p_start, p_expected_day, p_notes)
  returning * into v_l;
  -- money lent is a transfer/outflow, NOT an expense
  insert into public.transactions(user_id, type, direction, amount, txn_date, description, ref_type, ref_id)
  values (v_uid, 'lending', 'out', p_principal, p_start, 'Money lent to ' || v_l.person_name, 'loan', v_l.id);
  perform public.generate_interest_periods(v_l.id);
  return to_jsonb(v_l);
end $$;

-- Locks the period row, so concurrent/double submissions cannot over-record interest.
create or replace function public.record_interest_payment(
  p_period_id uuid, p_amount numeric, p_date date, p_notes text, p_key uuid)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_p public.loan_interest_periods; v_l public.loans; v_pay uuid; v_new numeric;
begin
  select * into v_p from public.loan_interest_periods where id = p_period_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  if p_key is not null and exists (select 1 from public.loan_interest_payments
      where user_id = v_uid and idempotency_key = p_key) then
    return to_jsonb(v_p);
  end if;
  if p_amount > v_p.expected_amount - v_p.paid_amount then raise exception 'OVERPAYMENT'; end if;
  select * into v_l from public.loans where id = v_p.loan_id;
  insert into public.loan_interest_payments(user_id, loan_id, period_id, amount, payment_date, notes, idempotency_key)
  values (v_uid, v_p.loan_id, v_p.id, p_amount, coalesce(p_date, current_date), p_notes, p_key)
  returning id into v_pay;
  v_new := v_p.paid_amount + p_amount;
  update public.loan_interest_periods
     set paid_amount = v_new,
         status = case when v_new >= expected_amount then 'paid' else 'partial' end
   where id = v_p.id returning * into v_p;
  insert into public.transactions(user_id, type, direction, amount, txn_date, description, ref_type, ref_id)
  values (v_uid, 'interest', 'in', p_amount, coalesce(p_date, current_date),
          v_l.person_name || ' interest', 'interest_payment', v_pay);
  return to_jsonb(v_p);
end $$;

-- Principal return is NOT income. Loan and history are kept.
create or replace function public.close_loan(p_loan_id uuid, p_amount numeric, p_date date, p_notes text)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_l public.loans;
begin
  select * into v_l from public.loans where id = p_loan_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_l.status = 'closed' then raise exception 'ALREADY_CLOSED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  perform public.generate_interest_periods(v_l.id);
  update public.loans set status = 'closed', principal_returned = p_amount,
         closed_on = coalesce(p_date, current_date),
         notes = coalesce(nullif(p_notes, ''), notes)
   where id = v_l.id returning * into v_l;
  insert into public.transactions(user_id, type, direction, amount, txn_date, description, ref_type, ref_id)
  values (v_uid, 'lending', 'in', p_amount, coalesce(p_date, current_date),
          'Principal returned by ' || v_l.person_name, 'loan_return', v_l.id);
  return to_jsonb(v_l);
end $$;

-- ---------------------------------------------- optional demo data (dev)
create or replace function public.seed_demo_data() returns void
language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid();
        v_start date := (date_trunc('month', current_date) - interval '3 months')::date + 4;
begin
  if exists (select 1 from public.loans where user_id = v_uid) then raise exception 'DEMO_EXISTS'; end if;
  update public.profiles set name = 'Santhosh', default_salary = 70000, salary_day = 5, onboarded = true where id = v_uid;
  insert into public.recurring_expenses(user_id, category_id, name, amount, due_day)
  select v_uid, (select id from public.categories where user_id = v_uid and lower(name) = lower(x.c)), x.n, x.a, x.d
  from (values ('Food','Food',5000,5),('Gas','Gas',500,8),('Medicine','Medicine',1000,10),
               ('Electricity','Electricity',1000,15),('RD','RD',7000,7),('Bike Due','Bike',7000,12)) as x(n, c, a, d)
  on conflict do nothing;
  perform public.savings_operation('deposit', 50000, current_date, 'Opening savings', null, null);
  perform public.create_loan('Sasi', null, 10000, 3, 'monthly_percentage', v_start, null, 'Demo loan');
  perform public.create_loan('Ravi', null, 20000, 2, 'monthly_percentage', v_start, null, 'Demo loan');
end $$;
