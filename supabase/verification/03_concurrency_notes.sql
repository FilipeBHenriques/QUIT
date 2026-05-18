-- Concurrency sanity check guidance:
-- Open two SQL sessions as same user and race send_time_gift with same balance.
-- One should succeed, one should fail with insufficient balance due to row lock + post-lock balance check.

begin;
select balance_seconds from public.time_wallets where user_id = auth.uid() for update;
-- In second session, run send_time_gift now; it should wait or fail after first commit.
commit;
