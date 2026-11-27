-- ===================================================================
-- KZYNOVEX CLASS COMPANION - SUPABASE POSTGRESQL SCHEMA
-- Complete RLS policies, indexes, triggers, and seed data
-- ===================================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. USERS TABLE
create table if not exists public.users (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  email text unique not null,
  role text not null check (role in ('student', 'admin')) default 'student',
  credits integer not null default 30,
  streak_count integer not null default 1,
  is_kzynovex_verified boolean not null default false,
  roll_no text,
  can_upload boolean not null default false,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- Ensure existing users table has new columns when migrating
alter table public.users add column if not exists roll_no text;
alter table public.users add column if not exists can_upload boolean not null default false;
alter table public.users add column if not exists unlocked_cosmetics jsonb not null default '[]'::jsonb;

create table if not exists public.quiz_credit_claims (
  user_id uuid not null references public.users(id) on delete cascade,
  quiz_id text not null,
  best_score integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, quiz_id)
);

-- 2. SUBJECTS TABLE
create table if not exists public.subjects (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  code text not null unique,
  professor text not null,
  min_attendance_pct integer not null default 75,
  color_hex text default '#6D28D9',
  created_at timestamptz not null default now()
);

-- 3. TIMETABLE SLOTS TABLE
create table if not exists public.timetable_slots (
  id uuid primary key default uuid_generate_v4(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  day_of_week integer not null check (day_of_week between 1 and 7), -- 1 = Monday, 7 = Sunday
  start_time time not null,
  end_time time not null,
  default_room text not null,
  created_at timestamptz not null default now()
);

-- 4. DAILY OVERRIDES TABLE
create table if not exists public.daily_overrides (
  id uuid primary key default uuid_generate_v4(),
  slot_id uuid not null references public.timetable_slots(id) on delete cascade,
  date date not null,
  status text not null check (status in ('scheduled', 'cancelled', 'rescheduled')) default 'scheduled',
  actual_room text,
  actual_start_time time,
  actual_end_time time,
  rescheduled_date date,
  topic_covered text,
  reported_by uuid references public.users(id) on delete set null,
  is_approved boolean not null default false,
  created_at timestamptz not null default now(),
  unique (slot_id, date)
);

-- Ensure existing daily_overrides table has time, date shift, and audit columns when migrating
alter table public.daily_overrides add column if not exists actual_start_time time;
alter table public.daily_overrides add column if not exists actual_end_time time;
alter table public.daily_overrides add column if not exists rescheduled_date date;
alter table public.daily_overrides add column if not exists meeting_url text;
alter table public.daily_overrides add column if not exists reported_by_name text;
alter table public.daily_overrides add column if not exists credits_awarded boolean not null default false;
alter table public.daily_overrides add column if not exists reviewed_by uuid references public.users(id) on delete set null;
alter table public.daily_overrides add column if not exists reviewed_at timestamptz;

-- 5. RESOURCES (VAULT) TABLE
create table if not exists public.resources (
  id uuid primary key default uuid_generate_v4(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  date date not null default current_date,
  uploader_id uuid references public.users(id) on delete set null,
  uploader_name text not null,
  title text not null,
  type text not null check (type in ('notes', 'pdf', 'folder', 'image', 'youtube')),
  url text not null,
  upvotes integer not null default 0,
  cost_credits integer not null default 5,
  is_approved boolean not null default false,
  created_at timestamptz not null default now()
);

-- 6. ATTENDANCE LOGS TABLE
create table if not exists public.attendance_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  date date not null default current_date,
  status text not null check (status in ('present', 'absent')),
  created_at timestamptz not null default now(),
  unique (user_id, subject_id, date)
);

-- ===================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ===================================================================

alter table public.users enable row level security;
alter table public.subjects enable row level security;
alter table public.timetable_slots enable row level security;
alter table public.daily_overrides enable row level security;
alter table public.resources enable row level security;
alter table public.attendance_logs enable row level security;

-- USERS POLICIES
drop policy if exists "Allow public read access to users" on public.users;
create policy "Allow public read access to users"
  on public.users for select using (true);

drop policy if exists "Users can update their own profile" on public.users;
create policy "Users can update their own profile"
  on public.users for update using (auth.uid() = id);

-- SUBJECTS POLICIES
drop policy if exists "Anyone can read subjects" on public.subjects;
create policy "Anyone can read subjects"
  on public.subjects for select using (true);

drop policy if exists "Admins can manage subjects" on public.subjects;
create policy "Admins can manage subjects"
  on public.subjects for all using (
    exists (select 1 from public.users where id = auth.uid() and role = 'admin')
  );

-- TIMETABLE SLOTS POLICIES
drop policy if exists "Anyone can view timetable slots" on public.timetable_slots;
create policy "Anyone can view timetable slots"
  on public.timetable_slots for select using (true);

drop policy if exists "Admins can manage timetable slots" on public.timetable_slots;
create policy "Admins can manage timetable slots"
  on public.timetable_slots for all using (
    exists (select 1 from public.users where id = auth.uid() and role = 'admin')
  );

-- DAILY OVERRIDES POLICIES
drop policy if exists "Anyone can view approved daily overrides" on public.daily_overrides;
create policy "Anyone can view approved daily overrides"
  on public.daily_overrides for select using (true);

drop policy if exists "Students can submit daily overrides" on public.daily_overrides;
create policy "Students can submit daily overrides"
  on public.daily_overrides for insert with check (auth.uid() = reported_by);

drop policy if exists "Admins can update and approve overrides" on public.daily_overrides;
create policy "Admins can update and approve overrides"
  on public.daily_overrides for update using (
    exists (select 1 from public.users where id = auth.uid() and role = 'admin')
  );

-- RESOURCES POLICIES
drop policy if exists "Anyone can read approved resources" on public.resources;
create policy "Anyone can read approved resources"
  on public.resources for select using (is_approved = true or uploader_id = auth.uid());

drop policy if exists "Users can submit resources" on public.resources;
create policy "Users can submit resources"
  on public.resources for insert with check (auth.uid() = uploader_id);

drop policy if exists "Admins can approve or delete resources" on public.resources;
create policy "Admins can approve or delete resources"
  on public.resources for all using (
    exists (select 1 from public.users where id = auth.uid() and role = 'admin')
  );

-- DEV / DEMO POLICIES (When using anon key without Supabase Auth login):
drop policy if exists "Dev/Demo: Allow anon write to subjects" on public.subjects;
create policy "Dev/Demo: Allow anon write to subjects"
  on public.subjects for all using (true) with check (true);

drop policy if exists "Dev/Demo: Allow anon write to timetable_slots" on public.timetable_slots;
create policy "Dev/Demo: Allow anon write to timetable_slots"
  on public.timetable_slots for all using (true) with check (true);

drop policy if exists "Dev/Demo: Allow anon write to daily_overrides" on public.daily_overrides;
create policy "Dev/Demo: Allow anon write to daily_overrides"
  on public.daily_overrides for all using (true) with check (true);

drop policy if exists "Dev/Demo: Allow anon write to resources" on public.resources;
create policy "Dev/Demo: Allow anon write to resources"
  on public.resources for all using (true) with check (true);

drop policy if exists "Users can upvote resources" on public.resources;
create policy "Users can upvote resources"
  on public.resources for update using (true);

-- ATTENDANCE LOGS POLICIES
drop policy if exists "Users can read and manage their own attendance" on public.attendance_logs;
create policy "Users can read and manage their own attendance"
  on public.attendance_logs for all using (auth.uid() = user_id);

-- ===================================================================
-- SEED DATA FOR DEMO / LOCAL TESTING
-- ===================================================================

insert into public.subjects (id, name, code, professor, min_attendance_pct, color_hex)
values
  ('11111111-1111-1111-1111-111111111111', 'Object Oriented Programming', 'CS201', 'Dr. Sarah Mitchell', 75, '#6D28D9'),
  ('22222222-2222-2222-2222-222222222222', 'Data Structures & Algorithms', 'CS204', 'Prof. Alan Vance', 75, '#4C1D95'),
  ('33333333-3333-3333-3333-333333333333', 'Digital Logic & Design', 'EE210', 'Dr. Elena Rostova', 75, '#059669'),
  ('44444444-4444-4444-4444-444444444444', 'Linear Algebra & Calculus', 'MA105', 'Prof. David Chen', 75, '#D97706')
on conflict (code) do nothing;

-- 7. ASSIGNMENTS TABLE (Admin uploaded metadata; student checkmarks are client-side only)
create table if not exists public.assignments (
  id uuid primary key default uuid_generate_v4(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text not null,
  description text default '',
  category text not null default 'assignment',
  deadline timestamptz not null,
  drive_url text,
  created_by text default 'Admin',
  created_at timestamptz not null default now()
);

alter table public.assignments
  add column if not exists category text not null default 'assignment';

alter table public.assignments enable row level security;

drop policy if exists "Allow public read access to assignments" on public.assignments;
create policy "Allow public read access to assignments"
  on public.assignments for select
  using (true);

drop policy if exists "Allow admins to manage assignments" on public.assignments;
create policy "Allow admins to manage assignments"
  on public.assignments for all
  using (true)
  with check (true);

create index if not exists idx_assignments_deadline on public.assignments(deadline);

-- ===================================================================
-- 8. QUIZZES TABLE (Optional Dedicated Table; app also auto-syncs via public.resources ccquiz://)
-- ===================================================================
create table if not exists public.quizzes (
  id uuid primary key default uuid_generate_v4(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text not null,
  description text default '',
  source_url text,
  questions jsonb not null default '[]'::jsonb,
  created_by text default 'Admin',
  created_at timestamptz not null default now()
);

alter table public.quizzes enable row level security;

drop policy if exists "Allow public read access to quizzes" on public.quizzes;
create policy "Allow public read access to quizzes"
  on public.quizzes for select
  using (true);

drop policy if exists "Allow admins to manage quizzes" on public.quizzes;
create policy "Allow admins to manage quizzes"
  on public.quizzes for all
  using (true)
  with check (true);


-- 9. STUDENT VERIFICATION REQUESTS & NOTE BOUNTIES (See supabase_security_fix.sql for full triggers/RPCs)
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

-- ===================================================================
-- 10. STORAGE BUCKET SETUP (Vault - Lecture Notes & Attachments)
-- ===================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lecture-notes',
  'lecture-notes',
  true,
  52428800, -- 50 MB limit (AppConfig.maxUploadBytes)
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 52428800;

-- Storage RLS Policies
drop policy if exists "Public Read Access for Lecture Notes" on storage.objects;
create policy "Public Read Access for Lecture Notes"
  on storage.objects for select
  using (bucket_id = 'lecture-notes');

drop policy if exists "Uploader Upload Access to Lecture Notes" on storage.objects;
create policy "Uploader Upload Access to Lecture Notes"
  on storage.objects for insert
  with check (bucket_id = 'lecture-notes');

drop policy if exists "Uploader Delete Access to Lecture Notes" on storage.objects;
create policy "Uploader Delete Access to Lecture Notes"
  on storage.objects for delete
  using (bucket_id = 'lecture-notes');


