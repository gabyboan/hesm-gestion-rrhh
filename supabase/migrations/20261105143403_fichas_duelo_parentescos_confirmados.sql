begin;
set local lock_timeout='3s';
set local statement_timeout='45s';

-- Equivalencias de uso interno confirmadas por el usuario al revisar fichas B/C/D.
-- No modifican licencias históricas ni incorporan tipos ajenos al catálogo Excel.
do $$ begin
  if (select count(*) from public.licencias_tipos where (id,codigo) in
    ((119,'19'),(121,'21'),(122,'22')))<>3 then
    raise exception 'Revisar los identificadores del catálogo antes de aplicar las equivalencias.';
  end if;
  if exists(select 1 from public.licencias_registros where tipo_id in(119,122)) then
    raise exception 'Revisar históricos antes de cambiar las equivalencias 19 y 22.';
  end if;
end; $$;
update public.licencias_tipos set nombre='Duelo por padre (código 19)',
  categoria_excel_id=11,columna_ficha=null,habilitado_para_carga=true where id=119;
update public.licencias_tipos set nombre='Duelo por abuelo o abuela (código 21)',
  categoria_excel_id=11,columna_ficha=null,habilitado_para_carga=true where id=121;
update public.licencias_tipos set nombre='Duelo por tío (código 22)',
  categoria_excel_id=11,columna_ficha=null,habilitado_para_carga=true where id=122;
commit;
