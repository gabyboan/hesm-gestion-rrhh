-- La clave foránea (dni, carrera_id) garantiza que la carrera pertenezca a la
-- persona. Para horas oficiales se admite cualquier carrera activa, incluida
-- RISAMC; las demás modalidades conservan la regla histórica.
alter table public.horas_registros
  drop constraint if exists ck_carrera_valida;
alter table public.horas_registros
  add constraint ck_carrera_valida
  check (
    tipo = 'OFICIAL'
    or carrera_id = any (array[1, 2, 3])
  );
