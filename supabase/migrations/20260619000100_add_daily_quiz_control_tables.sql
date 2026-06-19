create table if not exists public.kls_daily_quiz_settings (
  daily_quiz_setting_id bigserial primary key,
  quiz_id text not null unique,
  quiz_name text not null,
  source_quiz_id text,
  subject_id uuid,
  chapter_code text,
  difficulty_level text,
  total_questions integer not null default 0,
  time_limit integer not null default 15,
  is_enabled boolean not null default false,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_kls_daily_quiz_settings_is_enabled
  on public.kls_daily_quiz_settings (is_enabled);

create table if not exists public.kls_daily_quiz_questions (
  daily_quiz_question_id bigserial primary key,
  quiz_id text not null,
  question_id uuid not null,
  display_order integer not null default 1,
  created_at timestamptz not null default now(),
  unique (quiz_id, question_id)
);

create index if not exists idx_kls_daily_quiz_questions_quiz_id
  on public.kls_daily_quiz_questions (quiz_id);

alter table public.kls_daily_quiz_settings enable row level security;
alter table public.kls_daily_quiz_questions enable row level security;

drop policy if exists "Daily quiz settings are readable" on public.kls_daily_quiz_settings;
create policy "Daily quiz settings are readable"
on public.kls_daily_quiz_settings
for select
using (true);

drop policy if exists "Daily quiz settings are writable by admin" on public.kls_daily_quiz_settings;
create policy "Daily quiz settings are writable by admin"
on public.kls_daily_quiz_settings
for all
using (public.kls_is_admin())
with check (public.kls_is_admin());

drop policy if exists "Daily quiz questions are readable" on public.kls_daily_quiz_questions;
create policy "Daily quiz questions are readable"
on public.kls_daily_quiz_questions
for select
using (true);

drop policy if exists "Daily quiz questions are writable by admin" on public.kls_daily_quiz_questions;
create policy "Daily quiz questions are writable by admin"
on public.kls_daily_quiz_questions
for all
using (public.kls_is_admin())
with check (public.kls_is_admin());
