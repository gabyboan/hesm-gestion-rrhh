alter table public.personas
  add column if not exists horario_rotativo boolean not null default false;
comment on column public.personas.horario_rotativo is
  'Indica una modalidad rotativa de 30 horas semanales, con turnos de 6 horas sin dias ni turnos fijos confirmados.';
