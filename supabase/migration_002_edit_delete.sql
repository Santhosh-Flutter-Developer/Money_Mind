-- =====================================================================
-- MoneyMind migration 002 - edit / delete / reopen everything, time pickers
-- Run AFTER schema.sql (fresh install: schema.sql, then this file).
-- Existing installs: run only this file. Safe to run more than once.
-- =====================================================================

-- ---------------------------------------------------------- new columns
alter table public.app_settings add column if not exists reminder_hour int not null default 9
  check (reminder_hour between 0 and 23);
alter table public.app_settings add column if not exists reminder_minute int not null default 0
  check (reminder_minute between 0 and 59);
alter table public.budget_items add column if not exists due_time time;

-- -------------------------------------------- budget item guard (relaxed)
-- Completed items may now be edited or deleted; the linked expense transaction
-- follows. Items in a CLOSED cycle stay locked until the cycle is reopened.
create or replace function public.guard_budget_items() returns trigger
language plpgsql set search_path = public as $$
declare v_status text; v_budget uuid;
begin
  v_budget := case when tg_op = 'DELETE' then old.budget_id else new.budget_id end;
  select status into v_status from public.monthly_budgets where id = v_budget;
  if v_status = 'closed' then raise exception 'ALREADY_CLOSED'; end if;

  if tg_op = 'UPDATE' and old.status = 'completed' and new.status = 'completed' then
    update public.transactions
       set amount = new.amount, description = new.name, category_id = new.category_id
     where ref_type = 'budget_item' and ref_id = old.id;
  end if;

  if tg_op = 'DELETE' then
    delete from public.transactions where ref_type = 'budget_item' and ref_id = old.id;
    return old;
  end if;
  return new;
end $$;

-- Extra-income entries are locked while their cycle is closed.
create or replace function public.guard_income_txn() returns trigger
language plpgsql set search_path = public as $$
declare v_status text; v_ref text; v_budget uuid;
begin
  v_ref := case when tg_op = 'DELETE' then old.ref_type else new.ref_type end;
  if v_ref is distinct from 'other_income' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  v_budget := case when tg_op = 'DELETE' then old.budget_id else new.budget_id end;
  select status into v_status from public.monthly_budgets where id = v_budget;
  if v_status = 'closed' then raise exception 'ALREADY_CLOSED'; end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
drop trigger if exists trg_income_guard on public.transactions;
create trigger trg_income_guard before insert or update or delete on public.transactions
for each row execute function public.guard_income_txn();

-- ------------------------------------------------------ budget cycles
-- Reverses the savings transfer and opens a closed cycle for editing again.
create or replace function public.reopen_budget(p_budget_id uuid)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_b public.monthly_budgets;
        v_st public.savings_transactions; v_w public.savings_wallet;
begin
  select * into v_b from public.monthly_budgets where id = p_budget_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_b.status <> 'closed' then raise exception 'NOT_CLOSED'; end if;

  select * into v_st from public.savings_transactions
   where budget_id = v_b.id and type = 'monthly_savings' and user_id = v_uid;
  if found then
    select * into v_w from public.savings_wallet where user_id = v_uid for update;
    if v_w.balance < v_st.amount then raise exception 'INSUFFICIENT_BALANCE'; end if;
    update public.savings_wallet set balance = balance - v_st.amount where id = v_w.id;
    delete from public.transactions where ref_type = 'savings_txn' and ref_id = v_st.id;
    delete from public.savings_transactions where id = v_st.id;
  end if;

  update public.monthly_budgets set status = 'open', closed_at = null, savings_transferred = 0
   where id = v_b.id returning * into v_b;
  return to_jsonb(v_b);
end $$;

-- Deletes a whole cycle (items, salary and extra income entries). Reopens it first if closed.
create or replace function public.delete_budget(p_budget_id uuid)
returns void language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_b public.monthly_budgets;
begin
  select * into v_b from public.monthly_budgets where id = p_budget_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_b.status = 'closed' then perform public.reopen_budget(p_budget_id); end if;
  delete from public.budget_items where budget_id = v_b.id;            -- trigger removes their expenses
  delete from public.transactions where budget_id = v_b.id and user_id = v_uid;
  delete from public.monthly_budgets where id = v_b.id;
end $$;

-- ------------------------------------------------------- savings wallet
create or replace function public.update_savings_transaction(
  p_id uuid, p_amount numeric, p_date date, p_description text, p_notes text)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_w public.savings_wallet; v_t public.savings_transactions;
        v_old numeric; v_new numeric;
begin
  select * into v_w from public.savings_wallet where user_id = v_uid for update;
  select * into v_t from public.savings_transactions where id = p_id and user_id = v_uid;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_t.type not in ('deposit', 'withdrawal') then raise exception 'NOT_EDITABLE'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  v_old := case when v_t.type = 'withdrawal' then -v_t.amount else v_t.amount end;
  v_new := case when v_t.type = 'withdrawal' then -p_amount else p_amount end;
  if v_w.balance - v_old + v_new < 0 then raise exception 'INSUFFICIENT_BALANCE'; end if;
  update public.savings_wallet set balance = balance - v_old + v_new where id = v_w.id;
  update public.savings_transactions
     set amount = p_amount, txn_date = coalesce(p_date, txn_date),
         description = coalesce(nullif(p_description, ''), description), notes = p_notes,
         month_label = to_char(coalesce(p_date, txn_date), 'YYYY-MM')
   where id = p_id returning * into v_t;
  update public.transactions set amount = v_t.amount, txn_date = v_t.txn_date, description = v_t.description
   where ref_type = 'savings_txn' and ref_id = p_id;
  return jsonb_build_object('balance', v_w.balance - v_old + v_new);
end $$;

create or replace function public.delete_savings_transaction(p_id uuid)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_w public.savings_wallet; v_t public.savings_transactions; v_effect numeric;
begin
  select * into v_w from public.savings_wallet where user_id = v_uid for update;
  select * into v_t from public.savings_transactions where id = p_id and user_id = v_uid;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_t.type = 'monthly_savings' then raise exception 'NOT_EDITABLE'; end if;
  v_effect := case when v_t.type = 'withdrawal' then -v_t.amount else v_t.amount end;
  if v_w.balance - v_effect < 0 then raise exception 'INSUFFICIENT_BALANCE'; end if;
  update public.savings_wallet set balance = balance - v_effect where id = v_w.id;
  delete from public.transactions where ref_type = 'savings_txn' and ref_id = p_id;
  delete from public.savings_transactions where id = p_id;
  return jsonb_build_object('balance', v_w.balance - v_effect);
end $$;

-- --------------------------------------------------------------- lending
create or replace function public.update_interest_payment(
  p_payment_id uuid, p_amount numeric, p_date date, p_notes text)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_pay public.loan_interest_payments;
        v_p public.loan_interest_periods; v_paid numeric;
begin
  select * into v_pay from public.loan_interest_payments where id = p_payment_id and user_id = v_uid;
  if not found then raise exception 'NOT_FOUND'; end if;
  select * into v_p from public.loan_interest_periods where id = v_pay.period_id for update;
  select * into v_pay from public.loan_interest_payments where id = p_payment_id;
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  v_paid := v_p.paid_amount - v_pay.amount + p_amount;
  if v_paid > v_p.expected_amount then raise exception 'OVERPAYMENT'; end if;
  update public.loan_interest_payments
     set amount = p_amount, payment_date = coalesce(p_date, payment_date), notes = p_notes
   where id = p_payment_id returning * into v_pay;
  update public.loan_interest_periods
     set paid_amount = v_paid,
         status = case when v_paid >= expected_amount then 'paid' when v_paid > 0 then 'partial' else 'pending' end
   where id = v_p.id returning * into v_p;
  update public.transactions set amount = v_pay.amount, txn_date = v_pay.payment_date
   where ref_type = 'interest_payment' and ref_id = v_pay.id;
  return to_jsonb(v_p);
end $$;

create or replace function public.delete_interest_payment(p_payment_id uuid)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_pay public.loan_interest_payments;
        v_p public.loan_interest_periods; v_paid numeric;
begin
  select * into v_pay from public.loan_interest_payments where id = p_payment_id and user_id = v_uid;
  if not found then raise exception 'NOT_FOUND'; end if;
  select * into v_p from public.loan_interest_periods where id = v_pay.period_id for update;
  select * into v_pay from public.loan_interest_payments where id = p_payment_id;
  if not found then raise exception 'NOT_FOUND'; end if;
  v_paid := greatest(v_p.paid_amount - v_pay.amount, 0);
  delete from public.transactions where ref_type = 'interest_payment' and ref_id = v_pay.id;
  delete from public.loan_interest_payments where id = v_pay.id;
  update public.loan_interest_periods
     set paid_amount = v_paid,
         status = case when v_paid >= expected_amount then 'paid' when v_paid > 0 then 'partial' else 'pending' end
   where id = v_p.id returning * into v_p;
  return to_jsonb(v_p);
end $$;

-- Full loan edit. Months that already have payments keep their amounts; all other
-- months follow the new principal / rate / due day. Start date can change only while
-- no payments exist (periods are regenerated).
create or replace function public.update_loan(
  p_loan_id uuid, p_name text, p_phone text, p_principal numeric, p_rate numeric,
  p_start date, p_expected_day int, p_notes text)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_l public.loans;
begin
  select * into v_l from public.loans where id = p_loan_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if p_principal is null or p_principal <= 0 or p_rate is null or p_rate < 0 then
    raise exception 'INVALID_AMOUNT';
  end if;
  if p_start is not null and p_start <> v_l.start_date then
    if p_start > current_date then raise exception 'INVALID_DATE'; end if;
    if exists (select 1 from public.loan_interest_payments where loan_id = v_l.id) then
      raise exception 'HAS_PAYMENTS';
    end if;
    delete from public.loan_interest_periods where loan_id = v_l.id;
  end if;
  update public.loans
     set person_name = trim(p_name), phone = nullif(p_phone, ''), principal = p_principal, rate = p_rate,
         start_date = coalesce(p_start, start_date), expected_day = p_expected_day, notes = p_notes
   where id = v_l.id returning * into v_l;
  update public.loan_interest_periods
     set expected_amount = round(v_l.principal * v_l.rate / 100, 2),
         due_date = public.day_in_period(period_start, period_end, v_l.expected_day)
   where loan_id = v_l.id and paid_amount = 0;
  update public.transactions
     set amount = v_l.principal, txn_date = v_l.start_date, description = 'Money lent to ' || v_l.person_name
   where ref_type = 'loan' and ref_id = v_l.id;
  perform public.generate_interest_periods(v_l.id);
  return to_jsonb(v_l);
end $$;

-- Deletes a loan with all its interest periods, payments and ledger entries.
create or replace function public.delete_loan(p_loan_id uuid)
returns void language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_l public.loans;
begin
  select * into v_l from public.loans where id = p_loan_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  delete from public.transactions
   where user_id = v_uid and (
     (ref_type in ('loan', 'loan_return') and ref_id = p_loan_id) or
     (ref_type = 'interest_payment' and ref_id in
        (select id from public.loan_interest_payments where loan_id = p_loan_id)));
  delete from public.loans where id = p_loan_id;
end $$;

-- Undo "Close loan": removes the principal-return entry and makes the loan active again.
create or replace function public.reopen_loan(p_loan_id uuid)
returns jsonb language plpgsql set search_path = public as $$
declare v_uid uuid := auth.uid(); v_l public.loans;
begin
  select * into v_l from public.loans where id = p_loan_id and user_id = v_uid for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_l.status <> 'closed' then raise exception 'NOT_CLOSED'; end if;
  delete from public.transactions where ref_type = 'loan_return' and ref_id = v_l.id;
  update public.loans set status = 'active', principal_returned = 0, closed_on = null
   where id = v_l.id returning * into v_l;
  perform public.generate_interest_periods(v_l.id);
  return to_jsonb(v_l);
end $$;
