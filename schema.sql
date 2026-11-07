-- Shop & Earn Marketplace starter schema
-- Run this in Supabase SQL Editor on a NEW project.
-- Review policies and test with non-admin accounts before public launch.

create extension if not exists pgcrypto;

create type public.app_role as enum ('customer', 'admin');
create type public.purchase_status as enum ('pending', 'verified', 'rejected');
create type public.withdrawal_status as enum ('pending', 'paid', 'rejected');
create type public.ad_request_status as enum ('submitted', 'approved', 'rejected', 'paid', 'active', 'expired', 'paused');
create type public.wallet_tx_kind as enum ('credit', 'withdrawal_paid', 'adjustment');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text not null default '',
  role public.app_role not null default 'customer',
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  partner text not null check (partner in ('Jumia','Temu','Selar')),
  name text not null,
  category text not null default '',
  description text not null default '',
  price numeric(14,2) not null check (price >= 0),
  reward numeric(14,2) not null default 0 check (reward >= 0),
  image text,
  affiliate_url text not null,
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.wishlist (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.purchase_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  product_id uuid references public.products(id),
  product_name text not null,
  partner text not null,
  order_reference text,
  receipt_url text,
  status public.purchase_status not null default 'pending',
  admin_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  available_balance numeric(14,2) not null default 0 check (available_balance >= 0),
  reserved_balance numeric(14,2) not null default 0 check (reserved_balance >= 0),
  updated_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  kind public.wallet_tx_kind not null,
  amount numeric(14,2) not null check (amount > 0),
  note text,
  related_purchase_id uuid references public.purchase_submissions(id),
  related_withdrawal_id uuid,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  amount numeric(14,2) not null check (amount > 0),
  bank_name text not null,
  account_number text not null,
  account_name text not null,
  status public.withdrawal_status not null default 'pending',
  admin_note text,
  paid_at timestamptz,
  paid_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.wallet_transactions
  add constraint wallet_transactions_withdrawal_fk
  foreign key (related_withdrawal_id) references public.withdrawal_requests(id);

create table public.advertising_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  business_name text not null,
  contact_name text not null,
  phone text not null,
  description text not null,
  destination_url text,
  package_name text not null default 'weekly',
  status public.ad_request_status not null default 'submitted',
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references auth.users(id),
  action text not null,
  target_table text not null,
  target_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), coalesce(new.raw_user_meta_data->>'phone',''))
  on conflict (id) do nothing;
  insert into public.wallets (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Admin-only credit operation: validates caller role, amount, and customer wallet.
create or replace function public.admin_credit_wallet(p_user_id uuid, p_amount numeric, p_note text default 'Admin reward credit')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_tx uuid;
begin
  if not public.is_admin() then raise exception 'Administrator permission required'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Amount must be positive'; end if;
  if not exists (select 1 from auth.users where id = p_user_id) then raise exception 'Customer not found'; end if;
  insert into public.wallets(user_id) values (p_user_id) on conflict (user_id) do nothing;
  update public.wallets set available_balance = available_balance + p_amount, updated_at = now() where user_id = p_user_id;
  insert into public.wallet_transactions(user_id,kind,amount,note,created_by)
  values (p_user_id,'credit',p_amount,coalesce(p_note,'Admin reward credit'),auth.uid())
  returning id into new_tx;
  insert into public.admin_audit_log(admin_id,action,target_table,target_id,details)
  values (auth.uid(),'wallet_credit','wallets',p_user_id,jsonb_build_object('amount',p_amount,'note',p_note));
  return new_tx;
end;
$$;

-- Row-level security
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.wishlist enable row level security;
alter table public.purchase_submissions enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.advertising_requests enable row level security;
alter table public.admin_audit_log enable row level security;

create policy "Profiles readable by owner or admin" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "Users may update own basic profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid() and role = 'customer');
create policy "Products visible when active" on public.products for select using (is_active = true or public.is_admin());
create policy "Admins manage products" on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Users manage own wishlist" on public.wishlist for all to authenticated using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());
create policy "Users read own purchase submissions" on public.purchase_submissions for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "Users submit own purchases" on public.purchase_submissions for insert to authenticated with check (user_id = auth.uid());
create policy "Admins review purchases" on public.purchase_submissions for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Users read own wallet" on public.wallets for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "Users read own transactions" on public.wallet_transactions for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "Users read own withdrawal requests" on public.withdrawal_requests for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "Admins manage withdrawals" on public.withdrawal_requests for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Users submit own ad requests" on public.advertising_requests for insert to authenticated with check (user_id = auth.uid());
create policy "Users read own ad requests" on public.advertising_requests for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "Admins manage ad requests" on public.advertising_requests for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Admins read audit log" on public.admin_audit_log for select to authenticated using (public.is_admin());

grant execute on function public.admin_credit_wallet(uuid,numeric,text) to authenticated;

-- After creating your own account, promote it to admin from Supabase SQL Editor:
-- update public.profiles set role = 'admin' where id = 'YOUR_AUTH_USER_UUID';
-- Do this only for your own trusted account. Never expose service-role keys in frontend code.
