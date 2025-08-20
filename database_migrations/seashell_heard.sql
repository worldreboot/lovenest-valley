-- Create table to track which user has heard which seashell (voice note)
create table if not exists public.seashell_heard (
  seashell_id uuid not null references public.seashells(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  heard_at timestamptz not null default now(),
  constraint seashell_heard_pkey primary key (seashell_id, user_id)
);

alter table public.seashell_heard enable row level security;

-- Allow couple members to read heard receipts for seashells in their couple
create policy if not exists "seashell_heard_select_couple_members"
on public.seashell_heard
for select
using (
  exists (
    select 1 from public.seashells s
    join public.couples c on c.id = s.couple_id
    where s.id = seashell_id
      and (c.user1_id = auth.uid() or c.user2_id = auth.uid())
  )
);

-- Allow users to mark a seashell as heard if they belong to the couple that owns the seashell
create policy if not exists "seashell_heard_insert_couple_members"
on public.seashell_heard
for insert
with check (
  user_id = auth.uid() and
  exists (
    select 1 from public.seashells s
    join public.couples c on c.id = s.couple_id
    where s.id = seashell_id
      and (c.user1_id = auth.uid() or c.user2_id = auth.uid())
  )
);


