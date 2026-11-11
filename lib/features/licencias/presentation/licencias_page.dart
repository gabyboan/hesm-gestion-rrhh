import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/search_query.dart';
import '../../../core/widgets/app_search_field.dart';
import '../application/licencias_providers.dart';
import '../data/licencias_export.dart';
import '../domain/licencia.dart';

class LicenciasPage extends ConsumerStatefulWidget {
  const LicenciasPage({super.key});

  @override
  ConsumerState<LicenciasPage> createState() => _LicenciasPageState();
}

class _LicenciasPageState extends ConsumerState<LicenciasPage> {
  String _buscar = '';
  int? _categoriaId;
  int? _mes;
  bool _verAnuladas = false;
  bool _busy = false;

  Future<void> _form({LicenciaRegistro? registro}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LicenciaDialog(registro: registro),
    );
    if (saved == true && mounted) {
      ref.invalidate(licenciasRegistrosProvider);
      AppSnackBar.success(context,
          registro == null ? 'Licencia guardada' : 'Licencia modificada');
    }
  }

  Future<void> _anular(LicenciaRegistro row) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Anular licencia'),
              content: Text('¿Anular ${row.etiqueta} de ${row.nombre}, del '
                  '${DateFmt.ddmmyyyy(row.desde)} al ${DateFmt.ddmmyyyy(row.hasta)}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Anular')),
              ],
            ));
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (!await ref.read(licenciasRepoProvider).anular(row.id)) {
        throw StateError(
            'La licencia ya no está disponible. Actualizá el listado.');
      }
      ref.invalidate(licenciasRegistrosProvider);
      if (mounted) AppSnackBar.success(context, 'Licencia anulada');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportar(List<LicenciaRegistro> rows, int anio) async {
    setState(() => _busy = true);
    try {
      final saved = await exportLicenciasExcel(rows, anio);
      if (saved && mounted) AppSnackBar.success(context, 'Informe exportado');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pendientes(
      List<Map<String, dynamic>> rows, List<Map<String, dynamic>> resumen) {
    showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Historial del Excel pendiente de selección'),
              content: SizedBox(
                  width: 700,
                  child: SingleChildScrollView(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Este historial se conserva para revisión y no se incluye en las consultas, fichas ni totales de trabajo. '
                          'Antes de incorporarlo se debe confirmar qué datos extraer desde 2026.'),
                      const SizedBox(height: 16),
                      for (final tipo in resumen)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                              '${tipo['tipo']}: ${tipo['registros']} registros · ${tipo['dias']} días del Excel'),
                        ),
                      if (rows.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('Filas con datos para revisar:'),
                        ),
                      const SizedBox(height: 16),
                      for (final row in rows) ...[
                        Text(
                            'Fila ${row['origen_fila']} · ${(row['datos'] as Map)['B'] ?? ''}',
                            style: Theme.of(ctx).textTheme.titleSmall),
                        Text(row['motivo'].toString()),
                        SelectableText((row['datos'] as Map)
                            .entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join(' · ')),
                        const Divider(),
                      ],
                    ],
                  ))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final permisosAsync = ref.watch(licenciasPermisosProvider);
    return permisosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child:
              Text('No se pudieron verificar los permisos: ${cleanError(e)}')),
      data: (permisos) {
        if (!permisos.leer) {
          return const Center(
              child: Text('Sin permiso para consultar licencias.'));
        }
        final anio = ref.watch(licenciasAnioProvider);
        final tipos = ref.watch(licenciasTiposProvider).valueOrNull ?? [];
        final categorias = {
          for (final tipo in tipos)
            tipo.categoriaExcelId ?? tipo.id: tipo.nombre,
        };
        final pendientes =
            ref.watch(licenciasPendientesProvider).valueOrNull ?? [];
        final resumenImportado =
            ref.watch(licenciasImportadasResumenProvider).valueOrNull ?? [];
        final cantidadImportada = resumenImportado.fold<int>(
            0, (total, row) => total + (row['registros'] as num).toInt());
        return Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                      width: 300,
                      child: AppSearchField(
                        labelText: 'Buscar por nombre o DNI',
                        onChanged: (value) => setState(() => _buscar = value),
                      )),
                  SizedBox(
                      width: 135,
                      child: DropdownButtonFormField<int>(
                        initialValue: anio,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Año', border: OutlineInputBorder()),
                        items: [
                          for (var y = DateTime.now().year + 2; y >= 2026; y--)
                            DropdownMenuItem(value: y, child: Text('$y'))
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(licenciasAnioProvider.notifier).state =
                                value;
                          }
                        },
                      )),
                  SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<int>(
                        initialValue: _mes ?? 0,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Mes', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(
                              value: 0, child: Text('Todo el año')),
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                                value: m, child: Text(_meses[m - 1]))
                        ],
                        onChanged: (value) =>
                            setState(() => _mes = value == 0 ? null : value),
                      )),
                  SizedBox(
                      width: 270,
                      child: DropdownButtonFormField<int>(
                        initialValue: _categoriaId ?? 0,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Tipo de licencia',
                            border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(
                              value: 0, child: Text('Todas')),
                          for (final categoria in categorias.entries)
                            DropdownMenuItem(
                                value: categoria.key,
                                child: Text(categoria.value,
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: (value) => setState(
                            () => _categoriaId = value == 0 ? null : value),
                      )),
                  FilterChip(
                      label: const Text('Incluir anuladas'),
                      selected: _verAnuladas,
                      onSelected: (value) =>
                          setState(() => _verAnuladas = value)),
                  if (permisos.cargar)
                    FilledButton.icon(
                        onPressed: _busy ? null : () => _form(),
                        icon: const Icon(Icons.add),
                        label: const Text('Cargar licencia')),
                  IconButton(
                      tooltip: 'Actualizar datos y permisos',
                      onPressed: _busy
                          ? null
                          : () {
                              ref.invalidate(licenciasPermisosProvider);
                              ref.invalidate(licenciasRegistrosProvider);
                              ref.invalidate(licenciasTiposProvider);
                              ref.invalidate(licenciasPendientesProvider);
                              ref.invalidate(
                                  licenciasImportadasResumenProvider);
                            },
                      icon: const Icon(Icons.refresh)),
                ]),
            if (permisos.administrar &&
                (pendientes.isNotEmpty || resumenImportado.isNotEmpty))
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _pendientes(pendientes, resumenImportado),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(
                        'Excel para revisar: $cantidadImportada registros apartados · ${pendientes.length} filas con datos pendientes'),
                  )),
            const SizedBox(height: 12),
            Expanded(
                child: ref.watch(licenciasRegistrosProvider).when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                          child: Text(
                              'No se pudieron cargar las licencias: ${cleanError(e)}')),
                      data: (all) {
                        final inicio = DateTime(anio, _mes ?? 1, 1);
                        final fin = _mes == null
                            ? DateTime(anio, 12, 31)
                            : DateTime(anio, _mes! + 1, 0);
                        final search = SearchQuery(_buscar);
                        final rows = all
                            .where((row) =>
                                (_verAnuladas || !row.anulado) &&
                                (_categoriaId == null ||
                                    (row.categoriaExcelId ?? row.tipoId) ==
                                        _categoriaId) &&
                                !row.desde.isAfter(fin) &&
                                !row.hasta.isBefore(inicio) &&
                                search.matches([row.nombre, row.dni]))
                            .toList();
                        final dias = rows
                            .where((r) => !r.anulado)
                            .fold<int>(0, (sum, r) => sum + r.dias);
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                        '${rows.length} registros · $dias días registrados'),
                                    OutlinedButton.icon(
                                        onPressed: _busy || rows.isEmpty
                                            ? null
                                            : () => _exportar(rows, anio),
                                        icon: const Icon(
                                            Icons.file_download_outlined),
                                        label: const Text('Exportar informe')),
                                  ]),
                              const SizedBox(height: 8),
                              if (rows.isEmpty)
                                const Expanded(
                                    child: Center(
                                        child: Text(
                                            'No hay licencias para estos filtros.')))
                              else
                                Expanded(
                                    child: SingleChildScrollView(
                                  child: PaginatedDataTable(
                                    key: ValueKey(
                                        '$anio-$_mes-$_categoriaId-$_buscar-$_verAnuladas'),
                                    showCheckboxColumn: false,
                                    rowsPerPage: 15,
                                    availableRowsPerPage: const [15, 30, 60],
                                    columns: const [
                                      DataColumn(label: Text('DNI')),
                                      DataColumn(
                                          label: Text('Apellido y nombre')),
                                      DataColumn(label: Text('Licencia')),
                                      DataColumn(label: Text('Desde')),
                                      DataColumn(label: Text('Hasta')),
                                      DataColumn(
                                          label: Text('Días'), numeric: true),
                                      DataColumn(label: Text('Estado')),
                                      DataColumn(label: Text('Acciones'))
                                    ],
                                    source: _LicenciasSource(rows,
                                        administrar:
                                            permisos.administrar && !_busy,
                                        onEdit: (row) => _form(registro: row),
                                        onAnular: _anular),
                                  ),
                                )),
                            ]);
                      },
                    )),
          ]),
        );
      },
    );
  }
}

const _meses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre'
];

class _LicenciasSource extends DataTableSource {
  _LicenciasSource(this.rows,
      {required this.administrar,
      required this.onEdit,
      required this.onAnular});
  final List<LicenciaRegistro> rows;
  final bool administrar;
  final ValueChanged<LicenciaRegistro> onEdit;
  final ValueChanged<LicenciaRegistro> onAnular;

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final r = rows[index];
    return DataRow.byIndex(
        index: index,
        color: r.documentacionPendiente
            ? const WidgetStatePropertyAll(Color(0x18757575))
            : null,
        cells: [
          DataCell(Text('${r.dni}')),
          DataCell(Tooltip(
              message: [
                r.carrera,
                r.situacion,
                r.funcion,
                if (r.referenciaOrigen != null) r.referenciaOrigen!,
                if (r.esImprevisto) 'Origen: Imprevistos',
                if (r.numeroOrden != null) 'N.º de orden: ${r.numeroOrden}',
                r.observacion ?? ''
              ].where((s) => s.isNotEmpty).join('\n'),
              child: Text(r.nombre))),
          DataCell(Text(r.etiqueta)),
          DataCell(Text(DateFmt.ddmmyyyy(r.desde))),
          DataCell(Text(DateFmt.ddmmyyyy(r.hasta))),
          DataCell(Text('${r.dias}${r.esEstudio ? ' hábiles' : ''}')),
          DataCell(Text(r.estado)),
          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
            if (r.esImprevisto)
              const Text('Gestionar en Imprevistos')
            else if (administrar && !r.anulado) ...[
              IconButton(
                  tooltip: 'Modificar licencia',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(r)),
              IconButton(
                  tooltip: 'Anular licencia',
                  icon: const Icon(Icons.cancel_outlined),
                  onPressed: () => onAnular(r)),
            ],
          ])),
        ]);
  }

  @override
  int get rowCount => rows.length;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}

class _LicenciaDialog extends ConsumerStatefulWidget {
  const _LicenciaDialog({this.registro});
  final LicenciaRegistro? registro;
  @override
  ConsumerState<_LicenciaDialog> createState() => _LicenciaDialogState();
}

class _LicenciaDialogState extends ConsumerState<_LicenciaDialog> {
  final _formKey = GlobalKey<FormState>();
  late LicenciaPersona? _persona = widget.registro?.persona;
  late int? _tipoId = widget.registro?.tipoId;
  late DateTime _desde =
      widget.registro?.desde ?? DateUtils.dateOnly(DateTime.now());
  late final _dias =
      TextEditingController(text: '${widget.registro?.dias ?? 1}');
  late final _observacion =
      TextEditingController(text: widget.registro?.observacion ?? '');
  late final _dniFamiliar = TextEditingController(
      text: widget.registro?.dniFamiliar?.toString() ?? '');
  late final _numeroOrden = TextEditingController(
      text: widget.registro?.numeroOrden?.toString() ?? '');
  late final _cantidadFicha =
      TextEditingController(text: widget.registro?.cantidadFicha ?? '');
  String _buscar = '';
  String? _error;
  bool _saving = false;

  bool get _esEstudio =>
      ref
          .read(licenciasTiposProvider)
          .valueOrNull
          ?.any((t) => t.id == _tipoId && t.codigo == '29') ??
      (widget.registro?.esEstudio == true &&
          widget.registro?.tipoId == _tipoId);

  @override
  void dispose() {
    _dias.dispose();
    _observacion.dispose();
    _dniFamiliar.dispose();
    _numeroOrden.dispose();
    _cantidadFicha.dispose();
    super.dispose();
  }

  Future<void> _fecha() async {
    final value = await showDatePicker(
        context: context,
        initialDate: _desde,
        firstDate: DateTime(2026),
        lastDate: DateTime(2200));
    if (value != null && mounted) setState(() => _desde = value);
  }

  Future<void> _guardar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_persona == null) {
      setState(() => _error = 'Seleccioná una persona del listado.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dias = int.parse(_dias.text);
      final hasta = _esEstudio
          ? await ref.read(
              licenciasEstudioHastaProvider((desde: _desde, dias: dias)).future)
          : hastaLicencia(_desde, dias);
      await ref.read(licenciasRepoProvider).guardar(
          id: widget.registro?.id,
          dni: _persona!.dni,
          tipoId: _tipoId!,
          desde: _desde,
          hasta: hasta,
          observacion: _observacion.text,
          dniFamiliar: int.tryParse(_dniFamiliar.text.trim()),
          numeroOrden: int.tryParse(_numeroOrden.text.trim()),
          cantidadFicha: _cantidadFicha.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = cleanError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipos = ref.watch(licenciasTiposProvider);
    final count = int.tryParse(_dias.text) ?? 0;
    final esEstudio = _esEstudio;
    final hastaEstudio = esEstudio && count >= 1 && count <= 5
        ? ref.watch(licenciasEstudioHastaProvider((desde: _desde, dias: count)))
        : null;
    return PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(widget.registro == null
              ? 'Cargar licencia'
              : 'Modificar licencia'),
          content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                  child: Form(
                key: _formKey,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_persona == null) ...[
                        AppSearchField(
                            labelText:
                                'Buscar empleado por nombre, DNI o legajo',
                            autofocus: true,
                            onChanged: (value) =>
                                setState(() => _buscar = value)),
                        const SizedBox(height: 8),
                        SizedBox(
                            height: 190,
                            child: ref
                                .watch(licenciasPersonasProvider(_buscar))
                                .when(
                                  loading: () => const Center(
                                      child: CircularProgressIndicator()),
                                  error: (e, _) => Text(cleanError(e)),
                                  data: (personas) => personas.isEmpty
                                      ? const Center(
                                          child: Text(
                                              'No se encontraron personas.'))
                                      : ListView.builder(
                                          itemCount: personas.length,
                                          itemBuilder: (ctx, i) {
                                            final p = personas[i];
                                            return ListTile(
                                                title: Text(p.nombre),
                                                subtitle: Text(
                                                    'DNI ${p.dni} · ${p.carrera}${p.activo ? '' : ' · Inactivo'}'),
                                                onTap: _saving
                                                    ? null
                                                    : () => setState(
                                                        () => _persona = p));
                                          },
                                        ),
                                )),
                      ] else ...[
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_persona!.nombre),
                            subtitle: Text('DNI ${_persona!.dni}\n${[
                              _persona!.carrera,
                              _persona!.situacion,
                              _persona!.funcion
                            ].where((s) => s.isNotEmpty).join(' · ')}'),
                            trailing: widget.registro != null
                                ? null
                                : IconButton(
                                    tooltip: 'Cambiar persona',
                                    onPressed: _saving
                                        ? null
                                        : () => setState(() => _persona = null),
                                    icon: const Icon(Icons.person_search))),
                      ],
                      const SizedBox(height: 12),
                      tipos.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text(cleanError(e)),
                        data: (items) => DropdownButtonFormField<int>(
                          initialValue: _tipoId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Tipo de licencia',
                              border: OutlineInputBorder()),
                          items: [
                            for (final t in [
                              ...items.where(
                                  (t) => t.codigo != '43' && t.codigo != '98'),
                              if (widget.registro != null &&
                                  !items.any((t) =>
                                      t.id == widget.registro!.tipoId &&
                                      t.codigo != '43' &&
                                      t.codigo != '98'))
                                LicenciaTipo(
                                    id: widget.registro!.tipoId,
                                    nombre: widget.registro!.tipo,
                                    codigo: widget.registro!.codigo),
                            ])
                              DropdownMenuItem(
                                  value: t.id,
                                  child: Tooltip(
                                      message: t.descripcion ?? t.etiqueta,
                                      child: Text(t.etiqueta,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)))
                          ],
                          validator: (value) => value == null
                              ? 'Seleccioná un tipo de licencia.'
                              : null,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _tipoId = value),
                        ),
                      ),
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                              'Los imprevistos se cargan y modifican desde el módulo Imprevistos.')),
                      if (tipos.valueOrNull?.any((t) =>
                              t.id == _tipoId && t.columnaFicha == 'ART8') ==
                          true)
                        const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                                'Art. 8: el código se asigna por persona y año según el orden de carga: 43, 98 y 98. Cada carga puede abarcar varios días.')),
                      const SizedBox(height: 16),
                      Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                                onPressed: _saving ? null : _fecha,
                                icon: const Icon(Icons.calendar_today),
                                label:
                                    Text('Desde: ${DateFmt.ddmmyyyy(_desde)}')),
                            SizedBox(
                                width: 150,
                                child: TextFormField(
                                  controller: _dias,
                                  enabled: !_saving,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: esEstudio
                                          ? 'Días hábiles (máx. 5)'
                                          : 'Cantidad de días',
                                      border: const OutlineInputBorder()),
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) {
                                    final n = int.tryParse(value ?? '');
                                    final maximo = esEstudio ? 5 : 36500;
                                    return n == null || n < 1 || n > maximo
                                        ? 'Ingresá de 1 a $maximo.'
                                        : null;
                                  },
                                )),
                            if (esEstudio)
                              hastaEstudio?.when(
                                    data: (fecha) => Text(
                                        'Hasta: ${DateFmt.ddmmyyyy(fecha)}'),
                                    loading: () =>
                                        const Text('Calculando fecha hasta…'),
                                    error: (error, _) =>
                                        Text(cleanError(error)),
                                  ) ??
                                  const Text('Hasta: —')
                            else
                              Text(
                                  'Hasta: ${count > 0 && count <= 36500 ? DateFmt.ddmmyyyy(hastaLicencia(_desde, count)) : '—'}'),
                          ]),
                      const SizedBox(height: 8),
                      Text(esEstudio
                          ? 'Estudio: 20 días hábiles por persona y año, hasta 5 por solicitud. Se excluyen sábados, domingos y los feriados del calendario del sistema.'
                          : 'La cantidad incluye los días desde y hasta, como en el Excel.'),
                      const SizedBox(height: 16),
                      Wrap(spacing: 16, runSpacing: 12, children: [
                        SizedBox(
                            width: 280,
                            child: TextFormField(
                                controller: _dniFamiliar,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'DNI del familiar (opcional)',
                                    border: OutlineInputBorder()),
                                validator: (value) =>
                                    _enteroOpcional(value, 99999999))),
                        SizedBox(
                            width: 280,
                            child: TextFormField(
                                controller: _numeroOrden,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Número de orden (opcional)',
                                    border: OutlineInputBorder()),
                                validator: (value) =>
                                    _enteroOpcional(value, 2147483647))),
                      ]),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _observacion,
                          enabled: !_saving,
                          maxLines: 3,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                              labelText: 'Observación (opcional)',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _cantidadFicha,
                          enabled: !_saving,
                          maxLength: 12,
                          decoration: const InputDecoration(
                              labelText:
                                  'Cantidad en ficha (opcional, ej. 20/23)',
                              helperText:
                                  'Anotación literal para la planilla impresa. Los días del período se conservan aparte.',
                              border: OutlineInputBorder())),
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ]),
              ))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: _saving ||
                        (esEstudio && hastaEstudio?.hasValue != true) ||
                        !tipos.hasValue ||
                        (tipos.valueOrNull?.isEmpty ?? true)
                    ? null
                    : _guardar,
                child: Text(_saving ? 'Guardando...' : 'Guardar')),
          ],
        ));
  }

  String? _enteroOpcional(String? raw, int maximo) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    return value == null || value < 1 || value > maximo
        ? 'Ingresá un número válido.'
        : null;
  }
}
