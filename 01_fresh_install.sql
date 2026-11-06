-- =====================================================================
-- BASEIC Clothing: FRESH CLIENT SETUP (run once per client project;
-- safe to re-run). Supabase > SQL Editor > paste > Run.
--
-- Security model: the Render backend uses the service_role key, which
-- bypasses RLS. Browsers (anon / logged-in users) get NO direct table
-- access except admin READ via the app_metadata.role = 'admin' claim.
-- All writes happen in the backend after validation.
-- Never drops tables or deletes data.
-- =====================================================================

-- 1. TABLES -----------------------------------------------------------

create table if not exists public.products (
  id         text primary key check (char_length(id) between 1 and 100),
  name       text not null check (char_length(name) between 1 and 200),
  price      numeric(12,2) not null check (price >= 0),
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id              text primary key,                -- e.g. BC-261103-7877
  customer_name   text not null,
  phone_number    text not null,
  address         text not null,
  city            text not null,
  payment_method  text not null
                  check (payment_method in ('cod', 'bank')),
  customer_note   text not null default '',
  order_status    text not null default 'In process'
                  check (order_status in ('In process', 'Completed', 'Returned')),
  payment_status  text not null default 'In process'
                  check (payment_status in ('In process', 'Verified', 'Rejected')),
  items           jsonb not null
                  check (jsonb_typeof(items) = 'array'),  -- [{id,name,size,qty,price}]
  total_amount    numeric(12,2) not null check (total_amount >= 0),
  screenshot_url  text,                            -- unused (bucket is private); backend writes null
  screenshot_path text,                            -- object path inside payment-screenshots
  created_at      timestamptz not null default now()
);

-- 2. INDEXES ----------------------------------------------------------

create index if not exists orders_created_at_idx
  on public.orders (created_at desc);
create index if not exists orders_status_idx
  on public.orders (order_status, payment_status);

-- 3. ADMIN HELPER + RLS -----------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select coalesce((select auth.jwt()) -> 'app_metadata' ->> 'role', '') = 'admin'
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

alter table public.orders   enable row level security;
alter table public.products enable row level security;

-- Start from zero access, then grant only admin SELECT (RLS filters rows).
revoke all on public.orders   from anon, authenticated;
revoke all on public.products from anon, authenticated;
grant select on public.orders   to authenticated;
grant select on public.products to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies
                 where schemaname = 'public' and tablename = 'orders'
                   and policyname = 'Admins can read orders') then
    create policy "Admins can read orders"
      on public.orders for select to authenticated
      using (public.is_admin());
  end if;

  if not exists (select 1 from pg_policies
                 where schemaname = 'public' and tablename = 'products'
                   and policyname = 'Admins can read products') then
    create policy "Admins can read products"
      on public.products for select to authenticated
      using (public.is_admin());
  end if;
end $$;

-- 4. PRIVATE STORAGE BUCKET -------------------------------------------
-- Private; uploads/signed URLs are done by the backend (service_role).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('payment-screenshots', 'payment-screenshots', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public             = false,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (select 1 from pg_policies
                 where schemaname = 'storage' and tablename = 'objects'
                   and policyname = 'Admins can read payment screenshots') then
    create policy "Admins can read payment screenshots"
      on storage.objects for select to authenticated
      using (bucket_id = 'payment-screenshots' and public.is_admin());
  end if;
end $$;

-- 5. NOT INCLUDED (deliberately) -------------------------------------
-- * Dashboard views: the backend computes revenue/trending itself
--   (Verified + Completed only), so views would be dead code.
-- * pg_cron retention job: not required by the app; see the notes.
