-- Datos de ficha provenientes del listado de empleados. Se mantienen opcionales
-- para completar legajos existentes gradualmente y sin afectar la asistencia.
alter table public.personas
  add column if not exists cuil text,
  add column if not exists reloj text,
  add column if not exists indice text,
  add column if not exists sexo text,
  add column if not exists domicilio text,
  add column if not exists estado_civil text,
  add column if not exists numero_contacto text,
  add column if not exists fecha_ingreso date,
  add column if not exists formacion_estudio text,
  add column if not exists matricula text,
  add column if not exists nivel_escolaridad text,
  add column if not exists fecha_inicio_tarea_especifica date,
  add column if not exists observacion text,
  add column if not exists tipo_reemplazo text,
  add column if not exists disciplina text;
comment on column public.personas.reloj is
  'Numero de reloj. Se conserva como texto para admitir datos historicos especiales.';
comment on column public.personas.formacion_estudio is
  'Formacion o estudio declarado en el legajo.';
comment on column public.personas.matricula is
  'Matricula profesional declarada, cuando corresponda.';
comment on column public.personas.disciplina is
  'Disciplina declarada, principalmente para RISaMC.';
