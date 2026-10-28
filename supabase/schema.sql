-- Пятёрка: схема личного кабинета. Выполнить в Supabase → SQL Editor целиком.

-- Детские профили. family_id = auth.uid() родителя.
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  color text not null default '#2f9e5b',
  created_at timestamptz not null default now()
);
create index if not exists profiles_family_idx on public.profiles(family_id);

-- Прогресс профиля целиком (xp, стрик, короны, ошибки) — один JSON на профиль.
create table if not exists public.progress (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at bigint not null default 0,          -- мс, ставит клиент; побеждает более поздний
  saved_at timestamptz not null default now()
);

-- История уроков — одна строка на пройденный/прерванный урок.
create table if not exists public.lessons (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  topic text not null,
  passed boolean not null,
  first_try int not null default 0,
  total int not null default 0,
  wrong int not null default 0,
  xp int not null default 0,
  seconds int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists lessons_profile_idx on public.lessons(profile_id, created_at desc);

-- RLS: каждая семья видит только своё.
alter table public.profiles enable row level security;
alter table public.progress enable row level security;
alter table public.lessons  enable row level security;

drop policy if exists profiles_own on public.profiles;
create policy profiles_own on public.profiles
  for all using (family_id = auth.uid()) with check (family_id = auth.uid());

drop policy if exists progress_own on public.progress;
create policy progress_own on public.progress
  for all using (exists (select 1 from public.profiles p where p.id = progress.profile_id and p.family_id = auth.uid()))
  with check  (exists (select 1 from public.profiles p where p.id = progress.profile_id and p.family_id = auth.uid()));

drop policy if exists lessons_own on public.lessons;
create policy lessons_own on public.lessons
  for all using (exists (select 1 from public.profiles p where p.id = lessons.profile_id and p.family_id = auth.uid()))
  with check  (exists (select 1 from public.profiles p where p.id = lessons.profile_id and p.family_id = auth.uid()));

-- Сводка по дням для родительской панели.
create or replace view public.lesson_days as
  select profile_id, (created_at at time zone 'Europe/Minsk')::date as day,
         count(*) filter (where passed) as passed, sum(xp) as xp, sum(seconds) as seconds
  from public.lessons group by 1,2;
grant select on public.lesson_days to authenticated;
