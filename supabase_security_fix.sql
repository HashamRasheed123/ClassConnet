  -- ===================================================================
  -- KZYNOVEX CLASS COMPANION - SUPABASE ANTI-EXPLOIT & CREDIT GUARD
  -- Run this script once in your Supabase Dashboard -> SQL Editor.
  -- It secures BOTH new and older app versions at the database level.
  -- ===================================================================

  -- 0. Ensure required columns & constraints exist on existing tables
  alter table public.users add column if not exists roll_no text;
  alter table public.users add column if not exists avatar_url text;
  alter table public.users add column if not exists can_upload boolean not null default false;
  alter table public.users add column if not exists is_kzynovex_verified boolean not null default false;
  alter table public.users add column if not exists unlocked_cosmetics jsonb not null default '[]'::jsonb;

  alter table public.resources drop constraint if exists resources_type_check;
  alter table public.resources
    add constraint resources_type_check
    check (type in ('notes', 'pdf', 'folder', 'image', 'youtube'));

  alter table public.assignments
    add column if not exists category text not null default 'assignment';

  -- 1. Add audit & anti-duplicate columns to daily_overrides
  alter table public.daily_overrides
    add column if not exists meeting_url text;
  alter table public.daily_overrides
    add column if not exists reported_by_name text;
  alter table public.daily_overrides
    add column if not exists credits_awarded boolean not null default false;
  alter table public.daily_overrides
    add column if not exists reviewed_by uuid references public.users(id) on delete set null;
  alter table public.daily_overrides
    add column if not exists reviewed_at timestamptz;

  -- Ensure unique constraint on (slot_id, date) exists
  do $$
  begin
    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.daily_overrides'::regclass
        and contype = 'u'
    ) then
      alter table public.daily_overrides
        add constraint daily_overrides_slot_date_unique unique (slot_id, date);
    end if;
  exception when others then
    null;
  end $$;

  -- 2. Trigger: Protect public.users.credits, role, and privileges from direct client tampering
  -- Older app versions call `addCredits(30)` on report submit and upsert `credits` directly.
  -- This trigger silently ignores unauthorized `credits`/`role` changes on direct table writes,
  -- while allowing trusted SECURITY DEFINER RPCs (`app.bypass_credit_guard = 'on'`) to update them.
  create or replace function public.guard_user_credits_and_role()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    bypass text := current_setting('app.bypass_credit_guard', true);
    is_designated_admin boolean;
  begin
    if bypass = 'on' then
      return new;
    end if;

    is_designated_admin := lower(coalesce(new.email, '')) in (
      'fanhacker45f@gmail.com',
      'kzynovexinc@gmail.com',
      'muzammilsajid2000@gmail.com'
    );

    if tg_op = 'INSERT' then
      if not is_designated_admin then
        new.role := 'student';
        new.credits := least(greatest(coalesce(new.credits, 30), 0), 50);
        new.can_upload := false;
        new.is_kzynovex_verified := false;
      else
        new.credits := least(greatest(coalesce(new.credits, 500), 0), 10000);
      end if;
      return new;
    end if;

    if tg_op = 'UPDATE' then
      -- Preserve server-authoritative credits, role, and upload privileges
      -- so older app versions cannot inflate credits on report submission.
      new.credits := old.credits;
      if is_designated_admin then
        new.role := 'admin';
        new.is_kzynovex_verified := true;
      else
        new.role := old.role;
        new.is_kzynovex_verified := old.is_kzynovex_verified;
      end if;
      new.can_upload := old.can_upload;
      return new;
    end if;

    return new;
  end;
  $$;

  drop trigger if exists trg_guard_user_credits_and_role on public.users;
  create trigger trg_guard_user_credits_and_role
    before insert or update on public.users
    for each row
    execute function public.guard_user_credits_and_role();

  -- 3. Trigger: Prevent duplicate override spam, block non-admin self-approval,
  -- auto-populate reporter name, and award +30 credits ONLY once upon approval.
  create or replace function public.guard_daily_overrides()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    bypass text := current_setting('app.bypass_override_guard', true);
    reporter_is_admin boolean := false;
    reporter_name text;
    reporter_roll text;
  begin
    if new.reported_by is not null then
      select coalesce(u.role = 'admin', false),
             u.name,
             nullif(trim(coalesce(u.roll_no, '')), '')
        into reporter_is_admin, reporter_name, reporter_roll
        from public.users u
       where u.id = new.reported_by;

      reporter_is_admin := coalesce(reporter_is_admin, false);

      if (new.reported_by_name is null or trim(new.reported_by_name) = '')
        and reporter_name is not null then
        if reporter_roll is not null and trim(reporter_roll) <> '' then
          new.reported_by_name := reporter_name || ' (' || reporter_roll || ')';
        else
          new.reported_by_name := reporter_name;
        end if;
      end if;
    end if;

    if bypass <> 'on' and not reporter_is_admin then
      -- Block older apps or spammers from overwriting an existing report/override
      if tg_op = 'UPDATE' then
        raise exception 'A schedule report for this lecture and date already exists.'
          using errcode = '23505';
      end if;

      -- Non-admin submissions MUST start unapproved with 0 credits awarded
      new.is_approved := false;
      new.credits_awarded := false;
      new.reviewed_by := null;
      new.reviewed_at := null;
    end if;

    -- Award +30 credits exactly once when an override transitions false -> true
    if tg_op = 'UPDATE'
      and coalesce(old.is_approved, false) = false
      and new.is_approved = true
      and coalesce(old.credits_awarded, false) = false then
      new.credits_awarded := true;
      if new.reported_by is not null then
        perform set_config('app.bypass_credit_guard', 'on', true);
        update public.users
          set credits = credits + 30
        where id = new.reported_by;
      end if;
    end if;

    return new;
  end;
  $$;

  drop trigger if exists trg_guard_daily_overrides on public.daily_overrides;
  create trigger trg_guard_daily_overrides
    before insert or update on public.daily_overrides
    for each row
    execute function public.guard_daily_overrides();

  -- 4. Secure RPC: Admin Approve / Reject Override
  create or replace function public.admin_review_override(
    p_override_id uuid,
    p_admin_id uuid,
    p_approve boolean
  )
  returns jsonb
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    is_admin boolean;
    target_reporter uuid;
    already_awarded boolean;
  begin
    select exists(
      select 1
        from public.users
      where id = p_admin_id
        and (
          role = 'admin'
          or lower(coalesce(email, '')) in (
            'fanhacker45f@gmail.com',
            'kzynovexinc@gmail.com',
            'muzammilsajid2000@gmail.com'
          )
        )
    ) into is_admin;

    if not coalesce(is_admin, false) then
      raise exception 'Only admins can review schedule reports.' using errcode = '42501';
    end if;

    perform set_config('app.bypass_override_guard', 'on', true);
    perform set_config('app.bypass_credit_guard', 'on', true);

    if p_approve then
      select reported_by, credits_awarded
        into target_reporter, already_awarded
        from public.daily_overrides
        where id = p_override_id;

      update public.daily_overrides
        set is_approved = true,
            reviewed_by = p_admin_id,
            reviewed_at = now()
      where id = p_override_id;

      return jsonb_build_object(
        'status', 'approved',
        'reported_by', target_reporter,
        'credited', (target_reporter is not null and not coalesce(already_awarded, false))
      );
    else
      delete from public.daily_overrides where id = p_override_id;
      return jsonb_build_object('status', 'rejected', 'credited', false);
    end if;
  end;
  $$;

  -- 5. Secure RPC: Admin Update User (credits, role, verification, upload access)
  create or replace function public.admin_update_user_secure(
    p_admin_id uuid,
    p_target_user_id uuid,
    p_name text,
    p_email text,
    p_role text,
    p_credits integer,
    p_streak_count integer,
    p_is_verified boolean,
    p_can_upload boolean
  )
  returns void
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    is_admin boolean;
  begin
    select exists(
      select 1
        from public.users
      where id = p_admin_id
        and (
          role = 'admin'
          or lower(coalesce(email, '')) in (
            'fanhacker45f@gmail.com',
            'kzynovexinc@gmail.com',
            'muzammilsajid2000@gmail.com'
          )
        )
    ) into is_admin;

    if not coalesce(is_admin, false) then
      raise exception 'Only admins can modify user credits or roles.' using errcode = '42501';
    end if;

    perform set_config('app.bypass_credit_guard', 'on', true);

    update public.users
      set name = coalesce(nullif(trim(p_name), ''), name),
          email = coalesce(nullif(trim(p_email), ''), email),
          role = case when p_role in ('student', 'admin') then p_role else role end,
          credits = greatest(coalesce(p_credits, credits), 0),
          streak_count = greatest(coalesce(p_streak_count, streak_count), 0),
          is_kzynovex_verified = coalesce(p_is_verified, is_kzynovex_verified),
          can_upload = coalesce(p_can_upload, can_upload)
    where id = p_target_user_id;
  end;
  $$;

  -- 6. Secure RPCs: Bounded Quiz & Resource credit adjustments
  create or replace function public.award_quiz_credits(
    p_user_id uuid,
    p_delta integer
  )
  returns integer
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    new_credits integer;
  begin
    if p_delta is null or p_delta <= 0 or p_delta > 50 then
      raise exception 'Invalid quiz credit delta.' using errcode = '22023';
    end if;

    perform set_config('app.bypass_credit_guard', 'on', true);

    update public.users
      set credits = credits + p_delta
    where id = p_user_id
    returning credits into new_credits;

    return coalesce(new_credits, 0);
  end;
  $$;

  create or replace function public.adjust_resource_credits(
    p_user_id uuid,
    p_delta integer
  )
  returns integer
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    new_credits integer;
    u_verified boolean;
    u_role text;
  begin
    if p_delta is null or p_delta < -20 or p_delta > 50 or p_delta = 0 then
      raise exception 'Invalid resource credit adjustment.' using errcode = '22023';
    end if;

    if p_delta < 0 then
      select is_kzynovex_verified, role
        into u_verified, u_role
        from public.users
      where id = p_user_id;

      if not (coalesce(u_verified, false) or u_role = 'admin') then
        raise exception 'Verified Student Badge required to use or spend credits.'
          using errcode = '42501';
      end if;
    end if;

    perform set_config('app.bypass_credit_guard', 'on', true);

    update public.users
      set credits = greatest(credits + p_delta, 0)
    where id = p_user_id
    returning credits into new_credits;

    return coalesce(new_credits, 0);
  end;
  $$;

  -- Grant execute on RPCs to anon/authenticated clients
  grant execute on function public.admin_review_override(uuid, uuid, boolean) to anon, authenticated;
  grant execute on function public.admin_update_user_secure(uuid, uuid, text, text, text, integer, integer, boolean, boolean) to anon, authenticated;
  grant execute on function public.award_quiz_credits(uuid, integer) to anon, authenticated;
  grant execute on function public.adjust_resource_credits(uuid, integer) to anon, authenticated;

  -- ===================================================================
  -- 7. COSMETICS, STUDENT VERIFICATION BADGE & ANTI-SCAM NOTE BOUNTIES
  -- ===================================================================

  -- Table: Student Verification Requests (Name + Roll No -> Admin Approval)
  create table if not exists public.student_verification_requests (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references public.users(id) on delete cascade,
    email text not null,
    name text not null,
    roll_no text not null,
    status text not null check (status in ('pending', 'approved', 'rejected')) default 'pending',
    rejection_reason text,
    reviewed_by text,
    reviewed_at timestamptz,
    submitted_at timestamptz not null default now()
  );

  alter table public.student_verification_requests enable row level security;

  drop policy if exists "Public read student verification requests" on public.student_verification_requests;
  create policy "Public read student verification requests"
    on public.student_verification_requests for select using (true);

  drop policy if exists "Students can submit verification requests" on public.student_verification_requests;
  create policy "Students can submit verification requests"
    on public.student_verification_requests for insert with check (true);

  drop policy if exists "Dev/Demo: Allow update student verification requests" on public.student_verification_requests;
  create policy "Dev/Demo: Allow update student verification requests"
    on public.student_verification_requests for all using (true) with check (true);

  -- Table: Anti-Scam Escrowed Note Bounties
  create table if not exists public.note_bounties (
    id uuid primary key default uuid_generate_v4(),
    subject_id uuid references public.subjects(id) on delete set null,
    title text not null,
    description text not null default '',
    reward_credits integer not null check (reward_credits between 10 and 200),
    requester_id uuid references public.users(id) on delete cascade,
    requester_name text not null,
    requester_roll_no text,
    status text not null check (status in ('open', 'submitted', 'disputed', 'completed', 'cancelled')) default 'open',
    helper_id uuid references public.users(id) on delete set null,
    helper_name text,
    helper_roll_no text,
    solution_text text,
    solution_url text,
    dispute_reason text,
    payout_released boolean not null default false,
    submitted_at timestamptz,
    resolved_at timestamptz,
    resolved_by text,
    created_at timestamptz not null default now()
  );

  alter table public.note_bounties enable row level security;

  drop policy if exists "Public read note bounties" on public.note_bounties;
  create policy "Public read note bounties"
    on public.note_bounties for select using (true);

  drop policy if exists "Dev/Demo: Allow write note bounties" on public.note_bounties;
  create policy "Dev/Demo: Allow write note bounties"
    on public.note_bounties for all using (true) with check (true);

  -- Add unlocked_cosmetics column to users so theme/sound purchases survive reinstalls
  alter table public.users add column if not exists unlocked_cosmetics jsonb not null default '[]'::jsonb;

  -- Table: Server-side Quiz Credit Claims (prevents reinstall / clear-data quiz farming)
  create table if not exists public.quiz_credit_claims (
    user_id uuid not null references public.users(id) on delete cascade,
    quiz_id text not null,
    best_score integer not null default 0,
    updated_at timestamptz not null default now(),
    primary key (user_id, quiz_id)
  );

  alter table public.quiz_credit_claims enable row level security;

  drop policy if exists "Public read quiz credit claims" on public.quiz_credit_claims;
  create policy "Public read quiz credit claims"
    on public.quiz_credit_claims for select using (true);

  -- RPC: Spend Credits for Cosmetics Store (50-100+ Credits, atomic check + cloud save)
  drop function if exists public.spend_cosmetic_credits(uuid, integer);
  create or replace function public.spend_cosmetic_credits(
    p_user_id uuid,
    p_cost integer,
    p_item_id text default null
  )
  returns integer
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    current_credits integer;
    u_verified boolean;
    u_role text;
    u_unlocked jsonb;
    new_credits integer;
    clean_item text;
  begin
    if p_cost is null or p_cost <= 0 or p_cost > 150 then
      raise exception 'Invalid cosmetic cost.' using errcode = '22023';
    end if;

    select credits, is_kzynovex_verified, role, coalesce(unlocked_cosmetics, '[]'::jsonb)
      into current_credits, u_verified, u_role, u_unlocked
      from public.users
    where id = p_user_id
      for update;

    if current_credits is null then
      raise exception 'User account not found.' using errcode = 'P0002';
    end if;

    if not (coalesce(u_verified, false) or u_role = 'admin') then
      raise exception 'Verified Student Badge required to use credits. Request verification from an admin first.'
        using errcode = '42501';
    end if;

    clean_item := nullif(trim(coalesce(p_item_id, '')), '');
    if clean_item is not null and u_unlocked @> to_jsonb(clean_item) then
      return current_credits;
    end if;

    if current_credits < p_cost then
      raise exception 'Insufficient credits to unlock this cosmetic.' using errcode = '22023';
    end if;

    perform set_config('app.bypass_credit_guard', 'on', true);

    update public.users
      set credits = credits - p_cost,
          unlocked_cosmetics = case
            when clean_item is not null then coalesce(unlocked_cosmetics, '[]'::jsonb) || to_jsonb(clean_item)
            else unlocked_cosmetics
          end
    where id = p_user_id
    returning credits into new_credits;

    return coalesce(new_credits, 0);
  end;
  $$;

  -- RPC: Server-Side Quiz Credit Claim (idempotent per user & quiz)
  create or replace function public.claim_quiz_credits(
    p_user_id uuid,
    p_quiz_id text,
    p_score integer,
    p_total_questions integer
  )
  returns integer
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    old_best integer;
    delta integer;
    clean_qid text;
  begin
    clean_qid := nullif(trim(coalesce(p_quiz_id, '')), '');
    if clean_qid is null or p_total_questions is null or p_total_questions < 1 or p_total_questions > 200 then
      raise exception 'Invalid quiz claim payload.' using errcode = '22023';
    end if;
    if p_score is null or p_score < 0 or p_score > p_total_questions then
      raise exception 'Invalid quiz score.' using errcode = '22023';
    end if;

    select best_score into old_best
      from public.quiz_credit_claims
    where user_id = p_user_id and quiz_id = clean_qid
      for update;

    delta := least(greatest(p_score - coalesce(old_best, 0), 0), 50);

    insert into public.quiz_credit_claims (user_id, quiz_id, best_score, updated_at)
    values (p_user_id, clean_qid, p_score, now())
    on conflict (user_id, quiz_id) do update
      set best_score = greatest(public.quiz_credit_claims.best_score, excluded.best_score),
          updated_at = now();

    if delta > 0 then
      perform set_config('app.bypass_credit_guard', 'on', true);
      update public.users
        set credits = credits + delta
      where id = p_user_id;
    end if;

    return delta;
  end;
  $$;

  -- RPC: Admin Review Student Verified Badge Request
  create or replace function public.admin_review_student_verification(
    p_request_id uuid,
    p_admin_id uuid,
    p_approve boolean,
    p_reason text default null
  )
  returns jsonb
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    is_admin boolean;
    req_row record;
    admin_email text;
  begin
    select coalesce(
             u.role = 'admin'
             or lower(coalesce(u.email, '')) in (
               'fanhacker45f@gmail.com',
               'kzynovexinc@gmail.com',
               'muzammilsajid2000@gmail.com'
             ),
             false
           ),
           u.email
      into is_admin, admin_email
      from public.users u
     where u.id = p_admin_id;

    if not coalesce(is_admin, false) then
      raise exception 'Only admins can verify student badges.' using errcode = '42501';
    end if;

    select * into req_row
      from public.student_verification_requests
    where id = p_request_id
      for update;

    if req_row is null then
      raise exception 'Verification request not found.' using errcode = 'P0002';
    end if;

    perform set_config('app.bypass_credit_guard', 'on', true);

    if p_approve then
      update public.student_verification_requests
        set status = 'approved',
            reviewed_by = coalesce(admin_email, 'Admin'),
            reviewed_at = now()
      where id = p_request_id;

      if req_row.user_id is not null then
        update public.users
          set is_kzynovex_verified = true,
              name = coalesce(nullif(trim(req_row.name), ''), name),
              roll_no = coalesce(nullif(trim(req_row.roll_no), ''), roll_no)
        where id = req_row.user_id;
      end if;

      return jsonb_build_object('status', 'approved', 'user_id', req_row.user_id);
    else
      update public.student_verification_requests
        set status = 'rejected',
            rejection_reason = coalesce(nullif(trim(p_reason), ''), 'Roll number / name could not be verified.'),
            reviewed_by = coalesce(admin_email, 'Admin'),
            reviewed_at = now()
      where id = p_request_id;

      return jsonb_build_object('status', 'rejected', 'user_id', req_row.user_id);
    end if;
  end;
  $$;

  -- RPC: Create Note Bounty (Verified Users Only, Upfront Escrow Deduction)
  create or replace function public.create_note_bounty(
    p_id uuid,
    p_requester_id uuid,
    p_subject_id uuid,
    p_title text,
    p_description text,
    p_reward_credits integer
  )
  returns void
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    u_row record;
    v_subject_id uuid := p_subject_id;
    v_roll_no text;
  begin
    if p_reward_credits is null or p_reward_credits < 10 or p_reward_credits > 200 then
      raise exception 'Reward credits must be between 10 and 200.' using errcode = '22023';
    end if;

    select * into u_row
      from public.users
    where id = p_requester_id
      for update;

    if u_row is null then
      raise exception 'Requester account not found.' using errcode = 'P0002';
    end if;

    if not (
      coalesce(u_row.is_kzynovex_verified, false)
      or u_row.role = 'admin'
      or lower(coalesce(u_row.email, '')) in (
        'fanhacker45f@gmail.com',
        'kzynovexinc@gmail.com',
        'muzammilsajid2000@gmail.com'
      )
    ) then
      raise exception 'Verified Student Badge required to post bounties.' using errcode = '42501';
    end if;

    if coalesce(u_row.credits, 0) < p_reward_credits then
      raise exception 'Not enough credits to escrow this bounty.' using errcode = '22023';
    end if;

    if v_subject_id is not null and not exists (select 1 from public.subjects where id = v_subject_id) then
      v_subject_id := null;
    end if;

    v_roll_no := nullif(trim(coalesce(to_jsonb(u_row)->>'roll_no', '')), '');

    perform set_config('app.bypass_credit_guard', 'on', true);

    update public.users
      set credits = coalesce(credits, 0) - p_reward_credits
    where id = p_requester_id;

    insert into public.note_bounties (
      id, subject_id, title, description, reward_credits,
      requester_id, requester_name, requester_roll_no, status
    ) values (
      p_id, v_subject_id, trim(p_title), coalesce(trim(p_description), ''), p_reward_credits,
      p_requester_id, u_row.name, v_roll_no, 'open'
    );
  end;
  $$;

  -- RPC: Submit Bounty Solution (Verified Helpers Only, Cannot Self-Claim)
  create or replace function public.submit_bounty_solution(
    p_bounty_id uuid,
    p_helper_id uuid,
    p_solution_text text,
    p_solution_url text default null
  )
  returns void
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    h_row record;
    b_row record;
    v_helper_roll_no text;
  begin
    select * into h_row from public.users where id = p_helper_id;
    if h_row is null then
      raise exception 'Helper account not found.' using errcode = 'P0002';
    end if;

    if not (
      coalesce(h_row.is_kzynovex_verified, false)
      or h_row.role = 'admin'
      or lower(coalesce(h_row.email, '')) in (
        'fanhacker45f@gmail.com',
        'kzynovexinc@gmail.com',
        'muzammilsajid2000@gmail.com'
      )
    ) then
      raise exception 'Verified Student Badge required to claim bounties.' using errcode = '42501';
    end if;

    select * into b_row from public.note_bounties where id = p_bounty_id for update;
    if b_row is null then
      raise exception 'Bounty not found.' using errcode = 'P0002';
    end if;

    if b_row.requester_id = p_helper_id then
      raise exception 'You cannot claim your own bounty.' using errcode = '42501';
    end if;

    if b_row.status <> 'open' then
      raise exception 'This bounty is no longer open.' using errcode = '22023';
    end if;

    v_helper_roll_no := nullif(trim(coalesce(to_jsonb(h_row)->>'roll_no', '')), '');

    update public.note_bounties
      set status = 'submitted',
          helper_id = p_helper_id,
          helper_name = h_row.name,
          helper_roll_no = v_helper_roll_no,
          solution_text = p_solution_text,
          solution_url = nullif(trim(coalesce(p_solution_url, '')), ''),
          submitted_at = now()
    where id = p_bounty_id;
  end;
  $$;

  -- RPC: Resolve Escrowed Bounty Payout / Dispute / Admin Judge / Refund
  create or replace function public.resolve_bounty_payout(
    p_bounty_id uuid,
    p_actor_id uuid,
    p_action text,
    p_reason text default null
  )
  returns jsonb
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    actor_row record;
    b_row record;
    is_admin boolean;
    v_credited_user_id uuid;
    v_new_credits integer;
  begin
    select * into actor_row from public.users where id = p_actor_id;
    if actor_row is null then
      raise exception 'Actor account not found in cloud users.' using errcode = 'P0002';
    end if;
    is_admin := (
      actor_row.role = 'admin'
      or lower(coalesce(actor_row.email, '')) in (
        'fanhacker45f@gmail.com',
        'kzynovexinc@gmail.com',
        'muzammilsajid2000@gmail.com'
      )
    );

    select * into b_row from public.note_bounties where id = p_bounty_id for update;
    if b_row is null then
      raise exception 'Bounty not found.' using errcode = 'P0002';
    end if;

    perform set_config('app.bypass_credit_guard', 'on', true);

    if p_action = 'confirm' then
      if b_row.requester_id <> p_actor_id then
        raise exception 'Only the requester can confirm payout.' using errcode = '42501';
      end if;
      if b_row.status not in ('submitted', 'disputed') or b_row.payout_released then
        raise exception 'Bounty cannot be confirmed in its current state.' using errcode = '22023';
      end if;

      update public.note_bounties
        set status = 'completed',
            payout_released = true,
            resolved_at = now(),
            resolved_by = actor_row.name
      where id = p_bounty_id;

      if b_row.helper_id is not null then
        update public.users
          set credits = coalesce(credits, 0) + b_row.reward_credits
        where id = b_row.helper_id
        returning id, credits into v_credited_user_id, v_new_credits;
      end if;

      if v_credited_user_id is null
        and nullif(trim(coalesce(b_row.helper_roll_no, '')), '') is not null then
        update public.users
          set credits = coalesce(credits, 0) + b_row.reward_credits
        where lower(trim(coalesce(roll_no, ''))) = lower(trim(b_row.helper_roll_no))
        returning id, credits into v_credited_user_id, v_new_credits;
      end if;

      if v_credited_user_id is null then
        raise exception 'Helper user profile not found in cloud database — cannot release payout.'
          using errcode = 'P0002';
      end if;

      return jsonb_build_object(
        'status', 'completed',
        'credited_to', v_credited_user_id,
        'reward_credits', b_row.reward_credits,
        'helper_new_credits', v_new_credits
      );

    elsif p_action = 'dispute' then
      if b_row.requester_id <> p_actor_id and b_row.helper_id <> p_actor_id then
        raise exception 'Only the requester or helper can escalate this submission.' using errcode = '42501';
      end if;
      if b_row.status <> 'submitted' then
        raise exception 'Only submitted solutions can be disputed.' using errcode = '22023';
      end if;

      update public.note_bounties
        set status = 'disputed',
            dispute_reason = coalesce(nullif(trim(p_reason), ''), 'Submission does not match request.')
      where id = p_bounty_id;
      return jsonb_build_object('status', 'disputed');

    elsif p_action = 'admin_approve' then
      if not is_admin then
        raise exception 'Admin privileges required.' using errcode = '42501';
      end if;
      if b_row.status not in ('submitted', 'disputed') or b_row.payout_released then
        raise exception 'Bounty is not awaiting verification.' using errcode = '22023';
      end if;

      update public.note_bounties
        set status = 'completed',
            payout_released = true,
            resolved_at = now(),
            resolved_by = actor_row.name
      where id = p_bounty_id;

      if b_row.helper_id is not null then
        update public.users
          set credits = coalesce(credits, 0) + b_row.reward_credits
        where id = b_row.helper_id
        returning id, credits into v_credited_user_id, v_new_credits;
      end if;

      if v_credited_user_id is null
        and nullif(trim(coalesce(b_row.helper_roll_no, '')), '') is not null then
        update public.users
          set credits = coalesce(credits, 0) + b_row.reward_credits
        where lower(trim(coalesce(roll_no, ''))) = lower(trim(b_row.helper_roll_no))
        returning id, credits into v_credited_user_id, v_new_credits;
      end if;

      if v_credited_user_id is null then
        raise exception 'Helper user profile not found in cloud database — cannot release payout.'
          using errcode = 'P0002';
      end if;

      return jsonb_build_object(
        'status', 'completed',
        'credited_to', v_credited_user_id,
        'reward_credits', b_row.reward_credits,
        'helper_new_credits', v_new_credits
      );

    elsif p_action = 'admin_reject' then
      if not is_admin then
        raise exception 'Admin privileges required.' using errcode = '42501';
      end if;
      if b_row.payout_released then
        raise exception 'Payout has already been released.' using errcode = '22023';
      end if;

      update public.note_bounties
        set status = 'open',
            helper_id = null,
            helper_name = null,
            helper_roll_no = null,
            solution_text = null,
            solution_url = null,
            dispute_reason = null,
            submitted_at = null
      where id = p_bounty_id;
      return jsonb_build_object('status', 'open');

    elsif p_action = 'cancel' then
      if b_row.requester_id <> p_actor_id and not is_admin then
        raise exception 'Not authorized to cancel this bounty.' using errcode = '42501';
      end if;
      if b_row.status <> 'open' or b_row.payout_released then
        raise exception 'Only open bounties can be cancelled.' using errcode = '22023';
      end if;

      update public.note_bounties
        set status = 'cancelled',
            payout_released = true,
            resolved_at = now(),
            resolved_by = actor_row.name
      where id = p_bounty_id;

      if b_row.requester_id is not null then
        update public.users
          set credits = coalesce(credits, 0) + b_row.reward_credits
        where id = b_row.requester_id
        returning id, credits into v_credited_user_id, v_new_credits;
      end if;

      if v_credited_user_id is null
        and nullif(trim(coalesce(b_row.requester_roll_no, '')), '') is not null then
        update public.users
          set credits = coalesce(credits, 0) + b_row.reward_credits
        where lower(trim(coalesce(roll_no, ''))) = lower(trim(b_row.requester_roll_no))
        returning id, credits into v_credited_user_id, v_new_credits;
      end if;

      return jsonb_build_object(
        'status', 'cancelled',
        'refunded_to', v_credited_user_id,
        'reward_credits', b_row.reward_credits,
        'requester_new_credits', v_new_credits
      );
    else
      raise exception 'Unknown bounty action: %', p_action using errcode = '22023';
    end if;
  end;
  $$;

  grant execute on function public.spend_cosmetic_credits(uuid, integer, text) to anon, authenticated;
  grant execute on function public.claim_quiz_credits(uuid, text, integer, integer) to anon, authenticated;
  grant execute on function public.admin_review_student_verification(uuid, uuid, boolean, text) to anon, authenticated;
  grant execute on function public.create_note_bounty(uuid, uuid, uuid, text, text, integer) to anon, authenticated;
  grant execute on function public.submit_bounty_solution(uuid, uuid, text, text) to anon, authenticated;
  grant execute on function public.resolve_bounty_payout(uuid, uuid, text, text) to anon, authenticated;
