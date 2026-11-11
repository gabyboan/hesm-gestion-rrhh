begin;
set local lock_timeout='3s';
set local statement_timeout='45s';
-- Confirmación del usuario, 10/11/2026: un Franco de cantidad 2 anotado en una
-- fecha única representa dos francos. La duración calendario sigue siendo 1.
do $$ begin
  if not exists(select 1 from public.licencias_tipos where id=160 and codigo='60'
    and categoria_excel_id=4) then
    raise exception 'Revisar la variante Franco 60 antes de ampliar su cantidad de ficha.';
  end if;
end; $$;
alter table public.licencias_registros drop constraint licencias_cantidad_ficha_un_anio_check;
alter table public.licencias_registros add constraint licencias_cantidad_ficha_un_anio_check
  check(cantidad_dias_ficha is null or
    (extract(year from desde)=extract(year from hasta) and
      (cantidad_dias_ficha<=dias or (tipo_id=160 and dias=1 and cantidad_dias_ficha=2)))) not valid;
alter table public.licencias_registros validate constraint licencias_cantidad_ficha_un_anio_check;
comment on constraint licencias_cantidad_ficha_un_anio_check on public.licencias_registros is
  'Cantidad explícita verificada de papel. Solo Franco 60 admite 2 francos en una fecha única; conserva calendario=1.';
commit;
