-- Basic RPC happy-path checks
-- Preconditions: two users exist and are friends, both have wallets.

-- send friend request
select public.send_friend_request('00000000-0000-0000-0000-000000000002'::uuid);

-- request time
select public.request_time('00000000-0000-0000-0000-000000000002'::uuid, 300, 'Need focus block');

-- send gift
select public.send_time_gift('00000000-0000-0000-0000-000000000002'::uuid, 120, 'You got this');

-- view latest transfers
select id, sender_id, receiver_id, seconds, type, status, created_at
from public.time_transfers
order by created_at desc
limit 20;
