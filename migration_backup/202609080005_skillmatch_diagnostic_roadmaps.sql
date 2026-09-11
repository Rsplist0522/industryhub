
create table if not exists public.skill_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role_profile_id text not null,
  role_title text not null,
  role_profile jsonb not null,
  readiness_score numeric(5, 2) not null check (readiness_score between 0 and 100),
  completed_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.skill_assessment_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  assessment_id uuid not null references public.skill_assessments(id) on delete cascade,
  competency_id text not null,
  competency_name text not null,
  current_level numeric(5, 2) not null check (current_level between 0 and 100),
  target_level numeric(5, 2) not null check (target_level between 0 and 100),
  competency_weight numeric(8, 6) not null check (competency_weight >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  unique (assessment_id, competency_id)
);

create table if not exists public.learning_roadmaps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  assessment_id uuid not null references public.skill_assessments(id) on delete cascade,
  role_profile_id text not null,
  role_title text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.learning_roadmap_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  roadmap_id uuid not null references public.learning_roadmaps(id) on delete cascade,
  sequence_no integer not null check (sequence_no > 0),
  stage_title text not null,
  skill_id text not null,
  skill_name text not null,
  target_level numeric(5, 2) not null check (target_level between 0 and 100),
  gap_at_creation numeric(5, 2) not null check (gap_at_creation between 0 and 100),
  programme_id text,
  programme_name text,
  status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'completed')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (roadmap_id, sequence_no)
);

create index if not exists skill_assessments_user_role_idx
  on public.skill_assessments(user_id, role_profile_id, completed_at desc);
create index if not exists skill_assessment_scores_assessment_idx
  on public.skill_assessment_scores(assessment_id);
create index if not exists learning_roadmaps_user_role_idx
  on public.learning_roadmaps(user_id, role_profile_id, created_at desc);
create index if not exists learning_roadmap_items_roadmap_idx
  on public.learning_roadmap_items(roadmap_id, sequence_no);

drop trigger if exists learning_roadmaps_set_updated_at on public.learning_roadmaps;
create trigger learning_roadmaps_set_updated_at before update on public.learning_roadmaps
for each row execute function public.set_updated_at();

drop trigger if exists learning_roadmap_items_set_updated_at on public.learning_roadmap_items;
create trigger learning_roadmap_items_set_updated_at before update on public.learning_roadmap_items
for each row execute function public.set_updated_at();

alter table public.skill_assessments enable row level security;
alter table public.skill_assessment_scores enable row level security;
alter table public.learning_roadmaps enable row level security;
alter table public.learning_roadmap_items enable row level security;

drop policy if exists skill_assessments_manage_own on public.skill_assessments;
create policy skill_assessments_manage_own on public.skill_assessments
for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists skill_assessment_scores_manage_own on public.skill_assessment_scores;
create policy skill_assessment_scores_manage_own on public.skill_assessment_scores
for all to authenticated using (auth.uid() = user_id) with check (
  auth.uid() = user_id and exists (
    select 1 from public.skill_assessments assessment
    where assessment.id = assessment_id and assessment.user_id = auth.uid()
  )
);

drop policy if exists learning_roadmaps_manage_own on public.learning_roadmaps;
create policy learning_roadmaps_manage_own on public.learning_roadmaps
for all to authenticated using (auth.uid() = user_id) with check (
  auth.uid() = user_id and exists (
    select 1 from public.skill_assessments assessment
    where assessment.id = assessment_id and assessment.user_id = auth.uid()
  )
);

drop policy if exists learning_roadmap_items_manage_own on public.learning_roadmap_items;
create policy learning_roadmap_items_manage_own on public.learning_roadmap_items
for all to authenticated using (auth.uid() = user_id) with check (
  auth.uid() = user_id and exists (
    select 1 from public.learning_roadmaps roadmap
    where roadmap.id = roadmap_id and roadmap.user_id = auth.uid()
  )
);

grant select, insert, update, delete on table public.skill_assessments to authenticated;
grant select, insert, update, delete on table public.skill_assessment_scores to authenticated;
grant select, insert, update, delete on table public.learning_roadmaps to authenticated;
grant select, insert, update, delete on table public.learning_roadmap_items to authenticated;
