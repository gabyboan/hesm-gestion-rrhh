-- No se usan: tipo_reemplazo duplica la situacion de revista y disciplina
-- requiere un modelo especifico para RISaMC antes de incorporarse.
alter table public.personas
  drop column if exists tipo_reemplazo,
  drop column if exists disciplina;
