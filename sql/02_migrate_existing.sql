-- =====================================================================
-- BASEIC Clothing: MIGRATION for a project that already ran the old
-- script (deepseek_sql_...). Run THIS first, then 01_fresh_install.sql.
-- Safe to re-run. Does not drop tables, views or the cron job.
-- =====================================================================

-- A. Missing columns the backend inserts/selects --------------------------
alter table public.orders add column if not exists city            text;
alter table public.orders add column if not exists payment_method  text;
alter table public.orders add column if not exists customer_note   text;
alter table public.orders add column if not exists screenshot_path text;

update public.orders set city          = ''  where city is null;
update public.orders set customer_note = ''  where customer_note is null;
-- Old rows: a screenshot means bank transfer, otherwise cash on delivery.
update public.orders
   set payment_method = case when screenshot_url is not null then 'bank' else 'cod' end
 where payment_method is null;

alter table public.orders alter column city           set default '';
alter table public.orders alter column city           set not null;
alter table public.orders alter column customer_note  set default '';
alter table public.orders alter column customer_note  set not null;
alter table public.orders alter column payment_method set not null;

-- B. Status vocabulary: old UI values -> values the backend uses ----------
-- Drop old CHECKs on these two columns (names looked up, not assumed).
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.orders'::regclass and contype = 'c'
      and (pg_get_constraintdef(oid) ilike '%order_status%'
        or pg_get_constraintdef(oid) ilike '%payment_status%')
  loop
    execute format('alter table public.orders drop constraint %I', c.conname);
  end loop;
end $$;

-- Old "Paid/Shipped/Done" implied the payment was accepted.
update public.orders set payment_status = 'Verified'
 where payment_status = 'Pending' and order_status in ('Paid', 'Shipped', 'Done');
update public.orders set payment_status = 'In process' where payment_status = 'Pending';
update public.orders set payment_status = 'Rejected'   where payment_status = 'Failed';

update public.orders set order_status = 'Completed'  where order_status = 'Done';
update public.orders set order_status = 'Returned'   where order_status = 'Cancelled';
update public.orders set order_status = 'In process' where order_status in ('Pending', 'Paid', 'Shipped');

alter table public.orders alter column order_status   set default 'In process';
alter table public.orders alter column payment_status set default 'In process';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'orders_order_status_check') then
    alter table public.orders add constraint orders_order_status_check
      check (order_status in ('In process', 'Completed', 'Returned'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'orders_payment_status_check') then
    alter table public.orders add constraint orders_payment_status_check
      check (payment_status in ('In process', 'Verified', 'Rejected'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'orders_payment_method_check') then
    alter table public.orders add constraint orders_payment_method_check
      check (payment_method in ('cod', 'bank'));
  end if;
end $$;

-- C. Remove the insecure policies from the old script ---------------------
-- "using (true)" let ANY logged-in user read/edit every order; the storage
-- policy let anyone with a link view payment proofs.
drop policy if exists "Admin full access to orders"      on public.orders;
drop policy if exists "Admins can manage screenshots"    on storage.objects;
drop policy if exists "Public can view screenshots"      on storage.objects;

-- D. Old dashboard views: no longer used. Close them to the browser. ------
-- (They ran as owner, bypassing RLS, and counted retired statuses.)
do $$
declare v text;
begin
  foreach v in array array['monthly_income', 'weekly_income', 'trending_items'] loop
    if to_regclass('public.' || v) is not null then
      execute format('revoke all on public.%I from anon, authenticated', v);
    end if;
  end loop;
end $$;
-- Optional clean-up once you are happy:
-- drop view if exists public.monthly_income, public.weekly_income, public.trending_items;

-- E. Old 30-day anonymise job (pg_cron) -- NOT touched ---------------------
-- It blanks name/phone/address of every order older than 30 days, even ones
-- still being delivered, and leaves the screenshot FILE in storage. If you do
-- not want that, run:  select cron.unschedule('anonymize-old-orders-monthly');

-- F. Bucket is made private by 01_fresh_install.sql (run it next).
