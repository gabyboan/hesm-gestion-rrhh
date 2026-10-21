alter table public.persona_familiares
  add column fallecido boolean not null default false;
comment on column public.persona_familiares.fallecido is
  'Indica que el familiar fue marcado como fallecido.';
notify pgrst, 'reload schema';
