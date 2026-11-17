import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/widgets/app_search_field.dart';
import '../application/licencias_providers.dart';
import '../domain/licencia.dart';

class LicenciaDialog extends ConsumerStatefulWidget {
  const LicenciaDialog({super.key, this.registro});
  final LicenciaRegistro? registro;
  @override
  ConsumerState<LicenciaDialog> createState() => LicenciaDialogState();
}

class LicenciaDialogState extends ConsumerState<LicenciaDialog> {
  final _formKey = GlobalKey<FormState>();
  late LicenciaPersona? _persona = widget.registro?.persona;
  late int? _tipoId = widget.registro?.tipoId;
  late DateTime _desde =
      widget.registro?.desde ?? DateUtils.dateOnly(DateTime.now());
  late final _dias = TextEditingController(text: '$_diasIniciales');
  int get _diasIniciales =>
      widget.registro?.esEstudio == true || widget.registro?.esAnual == true
          ? widget.registro!.dias
          : widget.registro?.diasCalendario ?? widget.registro?.dias ?? 1;
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

  bool get _esAnual =>
      (ref
              .read(licenciasTiposProvider)
              .valueOrNull
              ?.any((t) => t.id == _tipoId && t.esAnual) ??
          false) ||
      (widget.registro?.esAnual == true && widget.registro?.tipoId == _tipoId);

  // Editar una observación no debe recalcular el período de una ficha existente.
  bool get _conservaPeriodoAnual =>
      _esAnual &&
      widget.registro != null &&
      _tipoId == widget.registro!.tipoId &&
      DateUtils.isSameDay(_desde, widget.registro!.desde) &&
      int.tryParse(_dias.text) == _diasIniciales;

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
      final hasta = _conservaPeriodoAnual
          ? widget.registro!.hasta
          : _esAnual
              ? await ref.read(
                  licenciasAnualHastaProvider((desde: _desde, dias: dias))
                      .future)
              : _esEstudio
                  ? await ref.read(
                      licenciasEstudioHastaProvider((desde: _desde, dias: dias))
                          .future)
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
    final esAnual = _esAnual;
    final usaHabiles = esEstudio || esAnual;
    final AsyncValue<DateTime>? hastaHabiles;
    if (_conservaPeriodoAnual) {
      hastaHabiles = AsyncData(widget.registro!.hasta);
    } else if (usaHabiles && count >= 1 && count <= (esEstudio ? 5 : 36500)) {
      final calculo = (desde: _desde, dias: count);
      hastaHabiles = ref.watch(esAnual
          ? licenciasAnualHastaProvider(calculo)
          : licenciasEstudioHastaProvider(calculo));
    } else {
      hastaHabiles = null;
    }
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
                                          : esAnual
                                              ? 'Días hábiles'
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
                            if (usaHabiles)
                              hastaHabiles?.when(
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
                          : esAnual
                              ? 'Anual: se cuentan días hábiles, excluyendo sábados, domingos y los feriados del calendario del sistema.'
                              : 'La cantidad incluye los días desde y hasta, como en el Excel.'),
                      if (_conservaPeriodoAnual &&
                          widget.registro?.cantidadDiasFicha != null)
                        const Text(
                            'Se conservan la cantidad verificada de la ficha de papel y su período original. Si cambiás la fecha o los días, se recalcula con el calendario.'),
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
                        (usaHabiles && hastaHabiles?.hasValue != true) ||
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
