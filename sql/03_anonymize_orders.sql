
-- 1. Enable pg_cron
create extension if not exists pg_cron;

-- 2. Create the anonymization function
create or replace function public.anonymize_old_orders()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.orders
  set
    customer_name = 'Anonymized',
    phone_number = '0000000000',
    address = 'Anonymized',
    city = 'Anonymized',
    customer_note = '',
    screenshot_path = null
  where
    created_at < now() - interval '30 days'
    and order_status in ('Completed', 'Returned')
    and customer_name is distinct from 'Anonymized';
end;
$$;

-- 3. Restrict direct execution
revoke all on function public.anonymize_old_orders() from public;
revoke all on function public.anonymize_old_orders() from anon, authenticated;

-- 4. Remove an existing job with the same name
select cron.unschedule(jobid)
from cron.job
where jobname = 'anonymize-old-orders-daily';

-- 5. Schedule one daily job
select cron.schedule(
  'anonymize-old-orders-daily',
  '0 0 * * *',
  'select public.anonymize_old_orders()'
);
