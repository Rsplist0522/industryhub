alter table public.training_programmes
  add column if not exists industry text;

alter table public.training_programmes
  add column if not exists target_roles text[] not null default '{}';

alter table public.training_programmes
  add column if not exists prerequisites text[];

alter table public.training_programmes
  add column if not exists metadata_note text not null default '';
