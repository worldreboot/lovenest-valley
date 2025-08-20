-- Mutual-completion daily prompts RPCs
-- This migration adds 4 SECURITY DEFINER functions. No new tables are created.
-- Functions:
-- 1) get_or_assign_today_question_for_couple(p_couple_id uuid) → (question_id uuid, text text)
-- 2) submit_daily_answer(p_question_id uuid, p_answer text) → text
-- 3) link_seed_to_daily_question(p_question_id uuid, p_seed_id uuid) → void
-- 4) evaluate_bloom_ready(p_seed_id uuid, p_required_waters int default 3) → text

set check_function_bodies = off;

-- Ensure stable search path for SECURITY DEFINER functions
alter database current set search_path = public, extensions;

-- 1) Assign or fetch today's question for a couple (UTC day)
create or replace function public.get_or_assign_today_question_for_couple(p_couple_id uuid)
returns table (question_id uuid, text text)
language plpgsql
security definer
as $$
declare
  v_req_user uuid := auth.uid();
  v_u1 uuid;
  v_u2 uuid;
  v_today date := (now() at time zone 'UTC')::date;
  v_qid uuid;
begin
  if v_req_user is null then
    raise exception 'Not authenticated';
  end if;

  -- Validate requester is member of the couple
  select c.user1_id, c.user2_id into v_u1, v_u2
  from couples c
  where c.id = p_couple_id;
  if v_u1 is null then
    raise exception 'Couple not found';
  end if;
  if v_req_user not in (v_u1, v_u2) then
    raise exception 'Permission denied: not a member of this couple';
  end if;

  -- Check if either partner already has a question assigned today
  select uq.question_id
    into v_qid
  from user_questions uq
  where uq.user_id in (v_u1, v_u2)
    and (uq.received_at at time zone 'UTC')::date = v_today
  limit 1;

  if v_qid is null then
    -- Choose a question neither partner has seen
    with seen as (
      select distinct question_id
      from user_questions
      where user_id in (v_u1, v_u2)
    )
    select q.id
      into v_qid
    from questions q
    left join seen s on s.question_id = q.id
    where s.question_id is null
    order by q.created_at nulls last, q.id
    limit 1;

    if v_qid is null then
      -- Fallback to newest question if all have been seen
      select id into v_qid from questions order by created_at desc nulls last, id desc limit 1;
    end if;

    if v_qid is null then
      raise exception 'No questions available';
    end if;

    -- Mark delivered for both partners (idempotent by day)
    insert into user_questions (user_id, question_id, received_at)
    values (v_u1, v_qid, now()), (v_u2, v_qid, now());
  end if;

  return query
  select q.id, q.text from questions q where q.id = v_qid;
end;
$$;

grant execute on function public.get_or_assign_today_question_for_couple(uuid) to authenticated;

-- 2) Upsert answer for the authed user; return status
create or replace function public.submit_daily_answer(p_question_id uuid, p_answer text)
returns text
language plpgsql
security definer
as $$
declare
  v_user uuid := auth.uid();
  v_couple_id uuid;
  v_other_user uuid;
  v_count int;
  v_status text := 'assigned';
  v_updated_rows int;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  -- Identify couple and partner
  select c.id,
         case when c.user1_id = v_user then c.user2_id else c.user1_id end
    into v_couple_id, v_other_user
  from couples c
  where c.user1_id = v_user or c.user2_id = v_user
  limit 1;

  if v_couple_id is null then
    raise exception 'Not in a couple';
  end if;

  -- Update existing answer if present
  update user_daily_question_answers a
     set answer = p_answer,
         created_at = now()
   where a.user_id = v_user
     and a.question_id = p_question_id;
  GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

  if v_updated_rows = 0 then
    -- Insert new
    insert into user_daily_question_answers (user_id, question_id, answer)
    values (v_user, p_question_id, p_answer);
  end if;

  -- Compute whether both answered
  select count(*) into v_count
  from user_daily_question_answers
  where question_id = p_question_id
    and user_id in (v_user, v_other_user);

  if v_count >= 2 then
    v_status := 'both_answered';
  end if;
  return v_status;
end;
$$;

grant execute on function public.submit_daily_answer(uuid, text) to authenticated;

-- 3) Link planted seed to the question across both partners
create or replace function public.link_seed_to_daily_question(p_question_id uuid, p_seed_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_user uuid := auth.uid();
  v_seed_couple uuid;
  v_u1 uuid; v_u2 uuid;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  -- Validate seed belongs to the caller's couple
  select s.couple_id into v_seed_couple from seeds s where s.id = p_seed_id;
  if v_seed_couple is null then
    raise exception 'Seed not found';
  end if;

  select c.user1_id, c.user2_id into v_u1, v_u2
  from couples c
  where c.id = v_seed_couple
    and (c.user1_id = v_user or c.user2_id = v_user)
  limit 1;
  if v_u1 is null then
    raise exception 'Permission denied: seed does not belong to your couple';
  end if;

  update user_daily_question_answers
     set planted_seed_id = p_seed_id,
         is_planted = true
   where question_id = p_question_id
     and user_id in (v_u1, v_u2);
end;
$$;

grant execute on function public.link_seed_to_daily_question(uuid, uuid) to authenticated;

-- 4) Evaluate bloom readiness based on answers and watering
create or replace function public.evaluate_bloom_ready(p_seed_id uuid, p_required_waters int default 3)
returns text
language plpgsql
security definer
as $$
declare
  v_user uuid := auth.uid();
  v_seed_couple uuid;
  v_qid uuid;
  v_num_answers int := 0;
  v_total_waters int := 0;
  v_distinct_waterers int := 0;
begin
  if v_user is null then
    return 'assigned';
  end if;

  select s.couple_id, s.question_id into v_seed_couple, v_qid
  from seeds s
  where s.id = p_seed_id;

  if v_seed_couple is null then
    return 'assigned';
  end if;

  -- Enforce membership
  if not exists (
    select 1 from couples c
    where c.id = v_seed_couple and (c.user1_id = v_user or c.user2_id = v_user)
  ) then
    return 'assigned';
  end if;

  -- Count answers
  select count(*) into v_num_answers
  from user_daily_question_answers
  where question_id = coalesce(v_qid, '00000000-0000-0000-0000-000000000000'::uuid);

  if v_num_answers < 2 then
    return 'assigned';
  end if;

  -- Count watering events on this seed
  select count(*), count(distinct user_id)
    into v_total_waters, v_distinct_waterers
  from waters_and_replies
  where seed_id = p_seed_id
    and type = 'water';

  if v_total_waters >= greatest(p_required_waters, 0) then
    return 'bloom_ready';
  end if;

  return 'both_answered';
end;
$$;

grant execute on function public.evaluate_bloom_ready(uuid, int) to authenticated;


