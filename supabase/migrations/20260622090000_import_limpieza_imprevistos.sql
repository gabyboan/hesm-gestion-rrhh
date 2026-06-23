-- Importa los imprevistos historicos desde C:\Users\som\Desktop\Limpieza.xlsx.
-- Fecha de importacion: 2026-06-22.
-- La carga es idempotente: si ya existe el imprevisto activo para DNI/carrera/fecha,
-- actualiza el numero_orden sin duplicar registros.

do $$
declare
  v_total integer;
  v_resueltos integer;
  v_afueras integer;
  v_insertados_o_actualizados integer;
  v_reporte jsonb;
begin
  create temp table tmp_limpieza_imprevistos_import (
    fila_excel integer not null,
    dni integer not null,
    apellido_nombre text not null,
    desde date not null,
    hasta date not null,
    cant integer not null,
    numero_orden integer not null
  ) on commit drop;

  insert into tmp_limpieza_imprevistos_import (
    fila_excel,
    dni,
    apellido_nombre,
    desde,
    hasta,
    cant,
    numero_orden
  ) values
    (2::integer, 31521669::integer, 'ALLES DANIELA SOLANGE'::text, '2026-01-06'::date, '2026-01-06'::date, 1::integer, 108::integer),
    (3::integer, 24831430::integer, 'ACEVEDO MIGUEL ANGEL'::text, '2026-01-20'::date, '2026-01-20'::date, 1::integer, 109::integer),
    (4::integer, 34495644::integer, 'BARSOTTI OTERO EMILIANO GABRIEL'::text, '2026-01-06'::date, '2026-01-06'::date, 1::integer, 110::integer),
    (5::integer, 34495644::integer, 'BARSOTTI OTERO EMILIANO GABRIEL'::text, '2026-01-09'::date, '2026-01-09'::date, 1::integer, 111::integer),
    (6::integer, 30164196::integer, 'BIER GLADYS BEATRIZ'::text, '2026-01-06'::date, '2026-01-06'::date, 1::integer, 112::integer),
    (7::integer, 34014588::integer, 'BENITEZ JESICA DESIREE'::text, '2026-01-16'::date, '2026-01-16'::date, 1::integer, 113::integer),
    (8::integer, 41154089::integer, 'CORTZ FLAVIO NICOLAS'::text, '2026-01-12'::date, '2026-01-12'::date, 1::integer, 114::integer),
    (9::integer, 38387748::integer, 'COMAS JUAN CARLOS ALBERTO'::text, '2026-01-06'::date, '2026-01-06'::date, 1::integer, 115::integer),
    (10::integer, 36103990::integer, 'COPELLO DEPARDON LEANDRO XAVIER'::text, '2026-01-02'::date, '2026-01-02'::date, 1::integer, 116::integer),
    (11::integer, 37223337::integer, 'DUARTE FACUNDO ARIEL'::text, '2026-01-07'::date, '2026-01-07'::date, 1::integer, 118::integer),
    (12::integer, 38054911::integer, 'GALLARDO GABRIEL AGUSTIN'::text, '2026-01-22'::date, '2026-01-22'::date, 1::integer, 119::integer),
    (13::integer, 32698866::integer, 'GONZALEZ MARIO SALVADOR'::text, '2026-01-07'::date, '2026-01-07'::date, 1::integer, 120::integer),
    (14::integer, 32698866::integer, 'GONZALEZ MARIO SALVADOR'::text, '2026-01-16'::date, '2026-01-16'::date, 1::integer, 121::integer),
    (15::integer, 27466836::integer, 'LEDESMA PAOLA SILVINA'::text, '2026-01-14'::date, '2026-01-14'::date, 1::integer, 122::integer),
    (16::integer, 26809281::integer, 'LUNA MAURICIO HERNAN'::text, '2026-01-14'::date, '2026-01-14'::date, 1::integer, 123::integer),
    (17::integer, 31351581::integer, 'LAGOS IVANA SOLEDAD'::text, '2026-01-12'::date, '2026-01-12'::date, 1::integer, 124::integer),
    (18::integer, 27466791::integer, 'LASTE ROXANA GUADALUPE'::text, '2026-01-08'::date, '2026-01-08'::date, 1::integer, 125::integer),
    (19::integer, 34904257::integer, 'PRETTIS MONICA AYELEN'::text, '2026-01-02'::date, '2026-01-02'::date, 1::integer, 127::integer),
    (20::integer, 27466612::integer, 'PASSI NADIA LORENA'::text, '2026-01-13'::date, '2026-01-13'::date, 1::integer, 128::integer),
    (21::integer, 36103953::integer, 'SALOMONE AQUILES JESUS'::text, '2026-01-13'::date, '2026-01-13'::date, 1::integer, 129::integer),
    (22::integer, 31232637::integer, 'VARRONE ROMINA GRISEL'::text, '2026-01-08'::date, '2026-01-08'::date, 1::integer, 130::integer),
    (23::integer, 39839039::integer, 'VILCHE KAREN AYELÉN'::text, '2026-01-13'::date, '2026-01-13'::date, 1::integer, 131::integer),
    (24::integer, 28676816::integer, 'VERA SERGIO DAVID'::text, '2026-01-20'::date, '2026-01-20'::date, 1::integer, 132::integer),
    (25::integer, 38387748::integer, 'COMAS JUAN CARLOS ALBERTO'::text, '2026-01-22'::date, '2026-01-22'::date, 1::integer, 218::integer),
    (26::integer, 31232343::integer, 'ARELLANO CINTIA ALEJANDRA'::text, '2026-01-22'::date, '2026-01-22'::date, 1::integer, 222::integer),
    (27::integer, 38387748::integer, 'COMAS JUAN CARLOS ALBERTO'::text, '2026-01-28'::date, '2026-01-28'::date, 1::integer, 256::integer),
    (28::integer, 26233569::integer, 'LATINO GRACIELA LORENA'::text, '2026-01-29'::date, '2026-01-29'::date, 1::integer, 265::integer),
    (29::integer, 30829346::integer, 'MENDEZ FACUNDO GABRIEL'::text, '2026-01-28'::date, '2026-01-28'::date, 1::integer, 267::integer),
    (30::integer, 32669064::integer, 'PEREZ ZACARIAS DANIEL'::text, '2026-01-29'::date, '2026-01-29'::date, 1::integer, 268::integer),
    (31::integer, 34495644::integer, 'BARSOTTI OTERO EMILIANO GABRIEL'::text, '2026-01-26'::date, '2026-01-26'::date, 1::integer, 274::integer),
    (32::integer, 28471521::integer, 'CACERES IVANA ARACELI'::text, '2026-02-02'::date, '2026-02-02'::date, 1::integer, 297::integer),
    (33::integer, 20298889::integer, 'FERNANDEZ GONZALO JAVIER'::text, '2026-02-02'::date, '2026-02-02'::date, 1::integer, 301::integer),
    (34::integer, 32698866::integer, 'GONZALEZ MARIO SALVADOR'::text, '2026-02-02'::date, '2026-02-02'::date, 1::integer, 302::integer),
    (35::integer, 27466612::integer, 'PASSI NADIA LORENA'::text, '2026-01-30'::date, '2026-01-30'::date, 1::integer, 307::integer),
    (36::integer, 34824814::integer, 'AGUILAR FLAVIA MARIA'::text, '2026-02-05'::date, '2026-02-05'::date, 1::integer, 399::integer),
    (37::integer, 41154089::integer, 'CORTZ FLAVIO NICOLAS'::text, '2026-01-06'::date, '2026-01-06'::date, 1::integer, 401::integer),
    (38::integer, 36103256::integer, 'MANRIQUE GEORGINA'::text, '2026-02-06'::date, '2026-02-06'::date, 1::integer, 403::integer),
    (39::integer, 33624862::integer, 'PRETTIS WALQUIRIA EVELYN'::text, '2026-02-04'::date, '2026-02-04'::date, 1::integer, 404::integer),
    (40::integer, 33009479::integer, 'POISSONNEAU ROMINA JOHANA'::text, '2026-02-05'::date, '2026-02-05'::date, 1::integer, 405::integer),
    (41::integer, 25033457::integer, 'RETAMOSO RITA SANDRA LORENA'::text, '2026-02-06'::date, '2026-02-06'::date, 1::integer, 406::integer),
    (42::integer, 25993506::integer, 'SAAVEDRA PABLO SEBASTIAN'::text, '2026-02-06'::date, '2026-02-06'::date, 1::integer, 407::integer),
    (43::integer, 24831430::integer, 'ACEVEDO MIGUEL ANGEL'::text, '2026-02-09'::date, '2026-02-09'::date, 1::integer, 410::integer),
    (44::integer, 28257010::integer, 'CUEVAS  FERNANDO GONZALO'::text, '2026-02-09'::date, '2026-02-09'::date, 1::integer, 411::integer),
    (45::integer, 37223337::integer, 'DUARTE FACUNDO ARIEL'::text, '2026-02-12'::date, '2026-02-12'::date, 1::integer, 495::integer),
    (46::integer, 25033457::integer, 'RETAMOSO RITA SANDRA LORENA'::text, '2026-02-12'::date, '2026-02-12'::date, 1::integer, 502::integer),
    (47::integer, 29346760::integer, 'OCAMPO ARMANDO ALEJANDRO'::text, '2026-02-19'::date, '2026-02-19'::date, 1::integer, 530::integer),
    (48::integer, 36103433::integer, 'CENTURION TAMARA DAIANA'::text, '2026-02-26'::date, '2026-02-26'::date, 1::integer, 540::integer),
    (49::integer, 16795755::integer, 'ABACA TERESITA'::text, '2026-02-18'::date, '2026-02-18'::date, 1::integer, 601::integer),
    (50::integer, 21856414::integer, 'AREVALO MONICA MARIA KARINA'::text, '2026-02-26'::date, '2026-02-26'::date, 1::integer, 622::integer),
    (51::integer, 24831430::integer, 'ACEVEDO MIGUEL ANGEL'::text, '2026-03-02'::date, '2026-03-02'::date, 1::integer, 623::integer),
    (52::integer, 28676358::integer, 'DELFINO LUCAS EMANUEL'::text, '2026-02-28'::date, '2026-02-28'::date, 1::integer, 631::integer),
    (53::integer, 28641917::integer, 'ESPINOSA CAROLINA ANALÍA'::text, '2026-02-24'::date, '2026-02-24'::date, 1::integer, 634::integer),
    (54::integer, 25307486::integer, 'MARTINEZ RODRIGO GASTON'::text, '2026-02-26'::date, '2026-02-26'::date, 1::integer, 646::integer),
    (55::integer, 37080871::integer, 'MENDOZA CYNTHIA LILIANA'::text, '2026-02-26'::date, '2026-02-26'::date, 1::integer, 647::integer),
    (56::integer, 33009479::integer, 'POISSONNEAU ROMINA JOHANA'::text, '2026-02-24'::date, '2026-02-24'::date, 1::integer, 651::integer),
    (57::integer, 32405990::integer, 'PAIZ GISELA ELISABET'::text, '2026-03-02'::date, '2026-03-02'::date, 1::integer, 652::integer),
    (58::integer, 33009479::integer, 'POISSONNEAU ROMINA JOHANA'::text, '2026-03-02'::date, '2026-03-02'::date, 1::integer, 652::integer),
    (59::integer, 20097638::integer, 'RONDAN LUCIA SUSANA TERESA'::text, '2026-03-02'::date, '2026-03-02'::date, 1::integer, 658::integer),
    (60::integer, 25993506::integer, 'SAAVEDRA PABLO SEBASTIAN'::text, '2026-02-24'::date, '2026-02-24'::date, 1::integer, 660::integer),
    (61::integer, 31232637::integer, 'VARRONE ROMINA GRISEL'::text, '2026-02-26'::date, '2026-02-26'::date, 1::integer, 665::integer),
    (62::integer, 34904647::integer, 'ALZUGARAY ESTEBAN GABRIEL'::text, '2026-03-03'::date, '2026-03-03'::date, 1::integer, 728::integer),
    (63::integer, 28257010::integer, 'CUEVAS  FERNANDO GONZALO'::text, '2026-03-04'::date, '2026-03-04'::date, 1::integer, 739::integer),
    (64::integer, 27466791::integer, 'LASTE ROXANA GUADALUPE'::text, '2026-03-04'::date, '2026-03-04'::date, 1::integer, 758::integer),
    (65::integer, 27834608::integer, 'MAIDANA BEATRIZ MABEL'::text, '2026-03-03'::date, '2026-03-03'::date, 1::integer, 760::integer),
    (66::integer, 25546384::integer, 'NANI CESAR RICARDO'::text, '2026-03-06'::date, '2026-03-06'::date, 1::integer, 762::integer),
    (67::integer, 30558993::integer, 'OLGUIN MARIA EMILIANA'::text, '2026-03-06'::date, '2026-03-06'::date, 1::integer, 763::integer),
    (68::integer, 25325280::integer, 'PEREYRA ANIBAL ENRIQUE'::text, '2026-02-24'::date, '2026-02-24'::date, 1::integer, 767::integer),
    (69::integer, 23982858::integer, 'RUIZ DINA TERESITA'::text, '2026-03-04'::date, '2026-03-04'::date, 1::integer, 772::integer),
    (70::integer, 25993506::integer, 'SAAVEDRA PABLO SEBASTIAN'::text, '2026-03-06'::date, '2026-03-06'::date, 1::integer, 776::integer),
    (71::integer, 28676816::integer, 'VERA SERGIO DAVID'::text, '2026-03-05'::date, '2026-03-05'::date, 1::integer, 781::integer),
    (72::integer, 39839039::integer, 'VILCHE KAREN AYELÉN'::text, '2026-03-06'::date, '2026-03-06'::date, 1::integer, 782::integer),
    (73::integer, 25684329::integer, 'ALVARENGA, MARIA CANDELA'::text, '2026-03-11'::date, '2026-03-11'::date, 1::integer, 792::integer),
    (74::integer, 30164196::integer, 'BIER GLADYS BEATRIZ'::text, '2026-03-03'::date, '2026-03-03'::date, 1::integer, 798::integer),
    (75::integer, 29024702::integer, 'BRITOS PAMELA MARÍA ELIDA'::text, '2026-01-05'::date, '2026-01-05'::date, 1::integer, 800::integer),
    (76::integer, 37080822::integer, 'CAMPOVILA JESICA MARIA AYELEN'::text, '2026-03-07'::date, '2026-03-07'::date, 1::integer, 801::integer),
    (77::integer, 24387455::integer, 'HERRMANN MIRNA BEATRIZ'::text, '2026-03-12'::date, '2026-03-12'::date, 1::integer, 810::integer),
    (78::integer, 35707005::integer, 'ARIN EVA MICAELA'::text, '2026-03-18'::date, '2026-03-18'::date, 1::integer, 931::integer),
    (79::integer, 23190949::integer, 'BOEYKENS MARIA SOL'::text, '2026-03-18'::date, '2026-03-18'::date, 1::integer, 933::integer),
    (80::integer, 41154089::integer, 'CORTZ FLAVIO NICOLAS'::text, '2026-03-13'::date, '2026-03-13'::date, 1::integer, 945::integer),
    (81::integer, 27006379::integer, 'DEANGELI SEBASTIAN ELIAS MAXIMILIANO'::text, '2026-03-13'::date, '2026-03-13'::date, 1::integer, 951::integer),
    (82::integer, 23476823::integer, 'DIAZ LORENA MERCEDES'::text, '2026-03-25'::date, '2026-03-25'::date, 1::integer, 954::integer),
    (83::integer, 32833768::integer, 'FRANCO GUILLERMINA ELIANA'::text, '2026-03-17'::date, '2026-03-17'::date, 1::integer, 956::integer),
    (84::integer, 38054911::integer, 'GALLARDO GABRIEL AGUSTIN'::text, '2026-03-16'::date, '2026-03-16'::date, 1::integer, 964::integer),
    (85::integer, 24387455::integer, 'HERRMANN MIRNA BEATRIZ'::text, '2026-03-11'::date, '2026-03-11'::date, 1::integer, 967::integer),
    (86::integer, 30558827::integer, 'LEMOS ESTHER SABRINA'::text, '2026-03-17'::date, '2026-03-17'::date, 1::integer, 971::integer),
    (87::integer, 26233569::integer, 'LATINO GRACIELA LORENA'::text, '2026-03-23'::date, '2026-03-23'::date, 1::integer, 972::integer),
    (88::integer, 26858568::integer, 'LEIVA ROSANA VANESA'::text, '2026-03-18'::date, '2026-03-18'::date, 1::integer, 973::integer),
    (89::integer, 27813899::integer, 'MEGLIO MARIA NAZARENA'::text, '2026-03-16'::date, '2026-03-16'::date, 1::integer, 975::integer),
    (90::integer, 32669213::integer, 'MEDINA CECILIA MARÍA EUGENIA'::text, '2026-03-14'::date, '2026-03-14'::date, 1::integer, 979::integer),
    (91::integer, 36103256::integer, 'MANRIQUE GEORGINA'::text, '2026-03-24'::date, '2026-03-24'::date, 1::integer, 980::integer),
    (92::integer, 27006908::integer, 'ZANOTTA MARIANA'::text, '2026-03-13'::date, '2026-03-13'::date, 1::integer, 1000::integer),
    (93::integer, 34299710::integer, 'DAVID MARIA ELIANA'::text, '2026-03-26'::date, '2026-03-26'::date, 1::integer, 1019::integer),
    (94::integer, 22026715::integer, 'LUBO ROXANA MARISA'::text, '2026-03-20'::date, '2026-03-20'::date, 1::integer, 1027::integer),
    (95::integer, 30829346::integer, 'MENDEZ FACUNDO GABRIEL'::text, '2026-03-27'::date, '2026-03-27'::date, 1::integer, 1031::integer),
    (96::integer, 27006588::integer, 'RAMIREZ MARCELA CECILIA'::text, '2026-03-27'::date, '2026-03-27'::date, 1::integer, 1039::integer),
    (97::integer, 25032930::integer, 'VIRGILIO MARINA ILEANA'::text, '2026-03-26'::date, '2026-03-26'::date, 1::integer, 1044::integer),
    (98::integer, 28471521::integer, 'CACERES IVANA ARACELI'::text, '2026-04-01'::date, '2026-04-01'::date, 1::integer, 1049::integer),
    (99::integer, 32833768::integer, 'FRANCO GUILLERMINA ELIANA'::text, '2026-03-31'::date, '2026-03-31'::date, 1::integer, 1052::integer),
    (100::integer, 33624862::integer, 'PRETTIS WALQUIRIA EVELYN'::text, '2026-03-31'::date, '2026-03-31'::date, 1::integer, 1057::integer),
    (101::integer, 34549332::integer, 'ARIEL VALERIA SILVINA'::text, '2026-04-06'::date, '2026-04-06'::date, 1::integer, 1211::integer),
    (102::integer, 30164196::integer, 'BIER GLADYS BEATRIZ'::text, '2026-04-06'::date, '2026-04-06'::date, 1::integer, 1215::integer),
    (103::integer, 23975730::integer, 'BELTZER SILVINA ALEJANDRA'::text, '2026-04-06'::date, '2026-04-06'::date, 1::integer, 1217::integer),
    (104::integer, 28641917::integer, 'ESPINOSA CAROLINA ANALÍA'::text, '2026-03-31'::date, '2026-03-31'::date, 1::integer, 1226::integer),
    (105::integer, 28647653::integer, 'ELCURA MARÍA JULIANA'::text, '2026-04-06'::date, '2026-04-06'::date, 1::integer, 1229::integer),
    (106::integer, 32833768::integer, 'FRANCO GUILLERMINA ELIANA'::text, '2026-04-06'::date, '2026-04-06'::date, 1::integer, 1232::integer),
    (107::integer, 28676175::integer, 'FERNANDEZ CINTIA BEATRIZ'::text, '2026-04-06'::date, '2026-04-06'::date, 1::integer, 1233::integer),
    (108::integer, 35175658::integer, 'GIMENEZ VALENTINA AYELEN'::text, '2026-04-06'::date, '2026-04-06'::date, 1::integer, 1234::integer),
    (109::integer, 35706366::integer, 'MULLER DANILO NEREO'::text, '2026-04-07'::date, '2026-04-07'::date, 1::integer, 1240::integer),
    (110::integer, 28471458::integer, 'MURGADO MARINA FERNANDA'::text, '2026-04-07'::date, '2026-04-07'::date, 1::integer, 1245::integer),
    (111::integer, 26048188::integer, 'PADILLA CLAUDIA NOEMI'::text, '2026-03-31'::date, '2026-03-31'::date, 1::integer, 1246::integer),
    (112::integer, 28512246::integer, 'QUINTEROS CLAUDIA MABEL'::text, '2026-04-07'::date, '2026-04-07'::date, 1::integer, 1248::integer),
    (113::integer, 23982858::integer, 'RUIZ DINA TERESITA'::text, '2026-04-07'::date, '2026-04-07'::date, 1::integer, 1249::integer),
    (114::integer, 30863685::integer, 'SALERNO HERNAN FEDERICO'::text, '2026-04-01'::date, '2026-04-01'::date, 1::integer, 1252::integer),
    (115::integer, 37289293::integer, 'ZAPATA LAUTARO ABEL'::text, '2026-04-06'::date, '2026-04-06'::date, 1::integer, 1255::integer),
    (116::integer, 33424348::integer, 'CASTRO JULIETA ANDREA'::text, '2026-04-09'::date, '2026-04-09'::date, 1::integer, 1256::integer),
    (117::integer, 27466791::integer, 'LASTE ROXANA GUADALUPE'::text, '2026-04-09'::date, '2026-04-09'::date, 1::integer, 1259::integer),
    (118::integer, 37382814::integer, 'LOPEZ ANTONELLA LUJAN'::text, '2026-04-09'::date, '2026-04-09'::date, 1::integer, 1260::integer),
    (119::integer, 39031433::integer, 'ACOSTA SANTIAGO AARON'::text, '2026-04-10'::date, '2026-04-10'::date, 1::integer, 1357::integer),
    (120::integer, 35708720::integer, 'FONSECA SEBASTIAN EXEQUIEL'::text, '2026-04-10'::date, '2026-04-10'::date, 1::integer, 1367::integer),
    (121::integer, 30187089::integer, 'LUCIDO ANGEL RAUL'::text, '2026-04-10'::date, '2026-04-10'::date, 1::integer, 1373::integer),
    (122::integer, 29855584::integer, 'PACIFICO ILEANA GABRIELA'::text, '2026-04-13'::date, '2026-04-13'::date, 1::integer, 1380::integer),
    (123::integer, 29620409::integer, 'VILLALBA SILVINA VANESA'::text, '2026-04-08'::date, '2026-04-08'::date, 1::integer, 1392::integer),
    (124::integer, 28257883::integer, 'ZATTI MARIA NATALIA'::text, '2026-04-10'::date, '2026-04-10'::date, 1::integer, 1395::integer),
    (125::integer, 33314323::integer, 'HALLER CEFERINO JONATHAN'::text, '2026-04-15'::date, '2026-04-15'::date, 1::integer, 1404::integer),
    (126::integer, 28793577::integer, 'PROSS LUCIANA GISELLA'::text, '2026-04-15'::date, '2026-04-15'::date, 1::integer, 1407::integer),
    (127::integer, 36651173::integer, 'CABRERA JUDITH ESTEFANIA'::text, '2026-04-15'::date, '2026-04-15'::date, 1::integer, 1410::integer),
    (128::integer, 16795755::integer, 'ABACA TERESITA'::text, '2026-04-16'::date, '2026-04-16'::date, 1::integer, 1411::integer),
    (129::integer, 36103990::integer, 'COPELLO DEPARDON LEANDRO XAVIER'::text, '2026-04-15'::date, '2026-04-15'::date, 1::integer, 1412::integer),
    (130::integer, 26048188::integer, 'PADILLA CLAUDIA NOEMI'::text, '2026-04-15'::date, '2026-04-15'::date, 1::integer, 1419::integer),
    (131::integer, 38054911::integer, 'GALLARDO GABRIEL AGUSTIN'::text, '2026-04-20'::date, '2026-04-20'::date, 1::integer, 1519::integer),
    (132::integer, 30322154::integer, 'LEGUIZAMON ÁNGEL EMANUEL'::text, '2026-04-19'::date, '2026-04-19'::date, 1::integer, 1526::integer),
    (133::integer, 26802667::integer, 'LOPEZ GABRIELA'::text, '2026-04-18'::date, '2026-04-18'::date, 1::integer, 1527::integer),
    (134::integer, 35706468::integer, 'MANGONA IRINA DESIREÉ'::text, '2026-04-20'::date, '2026-04-20'::date, 1::integer, 1531::integer),
    (135::integer, 32565396::integer, 'ALVAREZ MELISSA DANIELA'::text, '2026-04-27'::date, '2026-04-27'::date, 1::integer, 1533::integer),
    (136::integer, 28793461::integer, 'BLANCO WALTER FERNANDO'::text, '2026-04-22'::date, '2026-04-22'::date, 1::integer, 1539::integer),
    (137::integer, 28961975::integer, 'GARCIA ANABELLA ILEANA'::text, '2026-04-27'::date, '2026-04-27'::date, 1::integer, 1547::integer),
    (138::integer, 33502488::integer, 'RONDAN VILLAGRA DALILA MELISA S'::text, '2026-04-17'::date, '2026-04-17'::date, 1::integer, 1563::integer),
    (139::integer, 32833901::integer, 'SCHOENFELD MARIA BELEN'::text, '2026-04-24'::date, '2026-04-24'::date, 1::integer, 1567::integer),
    (140::integer, 29346371::integer, 'VILCHE DIEGO MAXIMILIANO'::text, '2026-04-21'::date, '2026-04-21'::date, 1::integer, 1571::integer),
    (141::integer, 31232343::integer, 'ARELLANO CINTIA ALEJANDRA'::text, '2026-04-28'::date, '2026-04-28'::date, 1::integer, 1575::integer),
    (142::integer, 30797312::integer, 'FERRACO NOELIA INES'::text, '2026-04-29'::date, '2026-04-29'::date, 1::integer, 1582::integer),
    (143::integer, 33314323::integer, 'HALLER CEFERINO JONATHAN'::text, '2026-04-30'::date, '2026-04-30'::date, 1::integer, 1585::integer),
    (144::integer, 22026715::integer, 'LUBO ROXANA MARISA'::text, '2026-04-29'::date, '2026-04-29'::date, 1::integer, 1586::integer),
    (145::integer, 25546384::integer, 'NANI CESAR RICARDO'::text, '2026-04-30'::date, '2026-04-30'::date, 1::integer, 1588::integer),
    (146::integer, 33424348::integer, 'CASTRO JULIETA ANDREA'::text, '2026-05-05'::date, '2026-05-05'::date, 1::integer, 1727::integer),
    (147::integer, 33424405::integer, 'CUELLO MIRIAM GABRIELA'::text, '2026-05-03'::date, '2026-05-03'::date, 1::integer, 1728::integer),
    (148::integer, 26048375::integer, 'DEPARDON ADRIANA LUCRECIA'::text, '2026-05-05'::date, '2026-05-05'::date, 1::integer, 1730::integer),
    (149::integer, 36269363::integer, 'PIOCAMPO FLORENCIA'::text, '2026-05-04'::date, '2026-05-04'::date, 1::integer, 1751::integer),
    (150::integer, 30863768::integer, 'RODRIGUEZ LUCIANO JOSE'::text, '2026-05-04'::date, '2026-05-04'::date, 1::integer, 1755::integer),
    (151::integer, 29620377::integer, 'TARABINI ANTONELLA MARIA'::text, '2026-05-03'::date, '2026-05-03'::date, 1::integer, 1762::integer),
    (152::integer, 35440441::integer, 'RETAMOSO LUCIANA ANTONELLA'::text, '2026-05-08'::date, '2026-05-08'::date, 1::integer, 1786::integer),
    (153::integer, 36704150::integer, 'ARRUA NOELIA YANET'::text, '2026-05-12'::date, '2026-05-12'::date, 1::integer, 1797::integer),
    (154::integer, 30187089::integer, 'LUCIDO ANGEL RAUL'::text, '2026-05-08'::date, '2026-05-08'::date, 1::integer, 1801::integer),
    (155::integer, 29855584::integer, 'PACIFICO ILEANA GABRIELA'::text, '2026-05-11'::date, '2026-05-11'::date, 1::integer, 1805::integer),
    (156::integer, 35707005::integer, 'ARIN EVA MICAELA'::text, '2026-05-13'::date, '2026-05-13'::date, 1::integer, 1916::integer),
    (157::integer, 37080299::integer, 'VILLAGRA JONATHAN ISMAEL'::text, '2026-05-14'::date, '2026-05-14'::date, 1::integer, 1921::integer),
    (158::integer, 25032930::integer, 'VIRGILIO MARINA ILEANA'::text, '2026-05-14'::date, '2026-05-14'::date, 1::integer, 1922::integer),
    (159::integer, 27157345::integer, 'BRITOS JUAN MANUEL'::text, '2026-05-17'::date, '2026-05-17'::date, 1::integer, 1924::integer),
    (160::integer, 25033457::integer, 'RETAMOSO RITA SANDRA LORENA'::text, '2026-05-15'::date, '2026-05-15'::date, 1::integer, 1928::integer),
    (161::integer, 28257584::integer, 'ESPINDOLA ABEL ALFONSO'::text, '2026-05-09'::date, '2026-05-09'::date, 1::integer, 1950::integer),
    (162::integer, 34904647::integer, 'ALZUGARAY ESTEBAN GABRIEL'::text, '2026-05-08'::date, '2026-05-08'::date, 1::integer, 2020::integer),
    (163::integer, 33424405::integer, 'CUELLO MIRIAM GABRIELA'::text, '2026-05-05'::date, '2026-05-05'::date, 1::integer, 2026::integer),
    (164::integer, 26858568::integer, 'LEIVA ROSANA VANESA'::text, '2026-05-13'::date, '2026-05-13'::date, 1::integer, 2027::integer),
    (165::integer, 26858568::integer, 'LEIVA ROSANA VANESA'::text, '2026-05-20'::date, '2026-05-20'::date, 1::integer, 2029::integer),
    (166::integer, 29538836::integer, 'SILVA MARIA ROBERTA'::text, '2026-05-18'::date, '2026-05-18'::date, 1::integer, 2035::integer),
    (167::integer, 32298914::integer, 'SANCHEZ CRISTIAN JESUS'::text, '2026-05-14'::date, '2026-05-14'::date, 1::integer, 2036::integer),
    (168::integer, 29024702::integer, 'BRITOS PAMELA MARÍA ELIDA'::text, '2026-05-22'::date, '2026-05-22'::date, 1::integer, 2039::integer),
    (169::integer, 28471521::integer, 'CACERES IVANA ARACELI'::text, '2026-05-22'::date, '2026-05-22'::date, 1::integer, 2043::integer),
    (170::integer, 31678229::integer, 'JAUREGUI CARLOS JONATHAN'::text, '2026-05-22'::date, '2026-05-22'::date, 1::integer, 2050::integer),
    (171::integer, 28647653::integer, 'ELCURA MARÍA JULIANA'::text, '2026-05-26'::date, '2026-05-26'::date, 1::integer, 2058::integer),
    (172::integer, 31333398::integer, 'FAEL BRENDA JESICA'::text, '2026-05-26'::date, '2026-05-26'::date, 1::integer, 2059::integer),
    (173::integer, 32405990::integer, 'PAIZ GISELA ELISABET'::text, '2026-05-22'::date, '2026-05-22'::date, 1::integer, 2061::integer),
    (174::integer, 33191064::integer, 'RODRIGUEZ ISIDRO RENATO'::text, '2026-05-26'::date, '2026-05-26'::date, 1::integer, 2062::integer),
    (175::integer, 30322029::integer, 'MILANO GABRIELA VERONICA'::text, '2026-05-26'::date, '2026-05-26'::date, 1::integer, 2103::integer),
    (176::integer, 27813899::integer, 'MEGLIO MARIA NAZARENA'::text, '2026-05-28'::date, '2026-05-28'::date, 1::integer, 2115::integer),
    (177::integer, 39839039::integer, 'VILCHE KAREN AYELÉN'::text, '2026-05-28'::date, '2026-05-28'::date, 1::integer, 2127::integer),
    (178::integer, 31351581::integer, 'LAGOS IVANA SOLEDAD'::text, '2026-05-29'::date, '2026-05-29'::date, 1::integer, 2183::integer),
    (179::integer, 29515482::integer, 'MARTINEZ DEBORA RAMONA'::text, '2026-05-29'::date, '2026-05-29'::date, 1::integer, 2184::integer),
    (180::integer, 32830961::integer, 'CARDOZO CRISTINA ALEJANDRA'::text, '2026-06-01'::date, '2026-06-01'::date, 1::integer, 2244::integer),
    (181::integer, 30782643::integer, 'MARTINEZ HECTOR MIGUEL'::text, '2026-06-04'::date, '2026-06-04'::date, 1::integer, 2338::integer),
    (182::integer, 36269208::integer, 'BELLOT DAIANA ELISABET'::text, '2026-06-01'::date, '2026-06-01'::date, 1::integer, 2346::integer),
    (183::integer, 25861901::integer, 'BRASSEUR NOELIA'::text, '2026-06-03'::date, '2026-06-03'::date, 1::integer, 2348::integer),
    (184::integer, 36703673::integer, 'LEIVA TAMARA ALEJANDRA'::text, '2026-06-08'::date, '2026-06-08'::date, 1::integer, 2354::integer),
    (185::integer, 30782643::integer, 'MARTINEZ HECTOR MIGUEL'::text, '2026-06-06'::date, '2026-06-06'::date, 1::integer, 2356::integer),
    (186::integer, 29346760::integer, 'OCAMPO ARMANDO ALEJANDRO'::text, '2026-06-08'::date, '2026-06-08'::date, 1::integer, 2361::integer),
    (187::integer, 29538836::integer, 'SILVA MARIA ROBERTA'::text, '2026-06-03'::date, '2026-06-03'::date, 1::integer, 2365::integer),
    (188::integer, 23207589::integer, 'WASINGER MARIA GRISELDA'::text, '2026-06-05'::date, '2026-06-05'::date, 1::integer, 2373::integer),
    (189::integer, 37080871::integer, 'MENDOZA CYNTHIA LILIANA'::text, '2026-06-08'::date, '2026-06-08'::date, 1::integer, 2374::integer),
    (190::integer, 25861901::integer, 'BRASSEUR NOELIA'::text, '2026-06-09'::date, '2026-06-09'::date, 1::integer, 2375::integer),
    (191::integer, 32114428::integer, 'MEDRANO NERINA'::text, '2026-06-09'::date, '2026-06-09'::date, 1::integer, 2383::integer),
    (192::integer, 29515482::integer, 'MARTINEZ DEBORA RAMONA'::text, '2026-06-12'::date, '2026-06-12'::date, 1::integer, 2579::integer),
    (193::integer, 29855584::integer, 'PACIFICO ILEANA GABRIELA'::text, '2026-06-10'::date, '2026-06-10'::date, 1::integer, 2582::integer),
    (194::integer, 28676175::integer, 'FERNANDEZ CINTIA BEATRIZ'::text, '2026-06-19'::date, '2026-06-19'::date, 1::integer, 2667::integer),
    (195::integer, 28257396::integer, 'FERRARI STELLA MARIS'::text, '2026-06-18'::date, '2026-06-18'::date, 1::integer, 2668::integer),
    (196::integer, 33502488::integer, 'RONDAN VILLAGRA DALILA MELISA S'::text, '2026-06-18'::date, '2026-06-18'::date, 1::integer, 2671::integer),
    (197::integer, 28676816::integer, 'VERA SERGIO DAVID'::text, '2026-06-18'::date, '2026-06-18'::date, 1::integer, 2672::integer);

  select count(*) into v_total
  from tmp_limpieza_imprevistos_import;

  with carreras_por_dni as (
    select
      vh.dni::integer as dni,
      count(distinct vh.carrera_id::integer) filter (where vh.carrera_id in (1, 3)) as carreras_validas,
      min(vh.carrera_id::integer) filter (where vh.carrera_id in (1, 3)) as carrera_id
    from public.vw_listado_horas vh
    join (select distinct dni from tmp_limpieza_imprevistos_import) i
      on i.dni = vh.dni::integer
    group by vh.dni::integer
  ), resueltos as (
    select
      i.*,
      c.carrera_id
    from tmp_limpieza_imprevistos_import i
    join carreras_por_dni c on c.dni = i.dni
    where c.carreras_validas = 1
  )
  insert into public.imprevistos_registros (
    dni,
    carrera_id,
    fecha,
    observacion,
    numero_orden,
    usuario_carga
  )
  select
    r.dni,
    r.carrera_id,
    r.desde,
    null,
    r.numero_orden,
    null
  from resueltos r
  on conflict (dni, carrera_id, fecha) where deleted_at is null
  do update set
    numero_orden = excluded.numero_orden,
    updated_at = now();

  get diagnostics v_insertados_o_actualizados = row_count;

  with carreras_por_dni as (
    select
      vh.dni::integer as dni,
      count(distinct vh.carrera_id::integer) filter (where vh.carrera_id in (1, 3)) as carreras_validas,
      min(vh.carrera_id::integer) filter (where vh.carrera_id in (1, 3)) as carrera_id,
      array_agg(distinct vh.carrera_id::integer order by vh.carrera_id::integer)
        filter (where vh.carrera_id in (1, 3)) as carreras
    from public.vw_listado_horas vh
    join (select distinct dni from tmp_limpieza_imprevistos_import) i
      on i.dni = vh.dni::integer
    group by vh.dni::integer
  ), clasificados as (
    select
      i.*,
      c.carreras_validas,
      c.carrera_id,
      c.carreras,
      case
        when c.dni is null then 'dni_sin_persona_en_vw_listado_horas'
        when coalesce(c.carreras_validas, 0) = 0 then 'dni_sin_carrera_1_o_3'
        when c.carreras_validas > 1 then 'dni_con_carrera_ambigua'
        else null
      end as motivo
    from tmp_limpieza_imprevistos_import i
    left join carreras_por_dni c on c.dni = i.dni
  )
  select
    count(*) filter (where motivo is null),
    count(*) filter (where motivo is not null),
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'fila_excel', fila_excel,
          'dni', dni,
          'apellido_nombre', apellido_nombre,
          'desde', desde,
          'numero_orden', numero_orden,
          'motivo', motivo,
          'carreras', carreras
        )
        order by fila_excel
      ) filter (where motivo is not null),
      '[]'::jsonb
    )
  into v_resueltos, v_afueras, v_reporte
  from clasificados;

  raise notice 'Limpieza.xlsx imprevistos: total=%, resueltos=%, insertados_o_actualizados=%, afuera=%',
    v_total,
    v_resueltos,
    v_insertados_o_actualizados,
    v_afueras;

  if v_afueras > 0 then
    raise warning 'Limpieza.xlsx imprevistos afuera: %', v_reporte;
  end if;
end;
$$;
