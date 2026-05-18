-- Verify that one authenticated user cannot read another user's wallet/profile unless policy allows.
-- Run this in Supabase SQL editor with test users by substituting jwt claims via auth.uid() context.

-- 1) As user A: should see own wallet exactly one row.
select count(*) as own_wallet_rows
from public.time_wallets
where user_id = auth.uid();

-- 2) As user A: direct select all should still only return A due to RLS.
select count(*) as visible_wallet_rows
from public.time_wallets;

-- 3) As user A: verify profile visibility includes self and accepted friends only.
select id, username
from public.profiles
order by created_at desc
limit 20;
