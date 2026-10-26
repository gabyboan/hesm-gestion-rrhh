import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../application/medicos_providers.dart';
import '../domain/control_parte_medico.dart';

class ControlParteMedicoDialog extends ConsumerStatefulWidget {
  const ControlParteMedicoDialog({super.key, this.parteId});
  final int? parteId;

  @override
  ConsumerState<ControlParteMedicoDialog> createState() =>
      _ControlParteMedicoDialogState();
}

class _ControlParteMedicoDialogState
    extends ConsumerState<ControlParteMedicoDialog> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _fecha = TextEditingController();
  final _dias = TextEditingController();
  final _medico = TextEditingController();
  final _matricula = TextEditingController();
  final _motivo = TextEditingController();
  DocumentoParteMedico? _documento;
  bool _busy = false;
  bool _puedeControlar = false;
  bool _puedeAdministrar = false;
  bool _rectificando = false;
  bool _contrastado = false;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    if (widget.parteId != null) _buscar(id: widget.parteId);
  }

  @override
  void dispose() {
    for (final controller in [
      _codigo,
      _fecha,
      _dias,
      _medico,
      _matricula,
      _motivo
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _buscar({int? id}) async {
    setState(() {
      _busy = true;
      _error = null;
      _mensaje = null;
      _documento = null;
      _contrastado = false;
      _rectificando = false;
    });
    try {
      final documento = await ref
          .read(medicosRepoProvider)
          .documento(id: id, codigo: id == null ? _codigo.text : null);
      final permisos = await Future.wait([
        ref.read(puedeControlarMedicosProvider.future),
        ref.read(puedeAdministrarMedicosProvider.future),
      ]);
      if (!mounted) return;
      final ultimo = documento.ultimoControl;
      _codigo.text = documento.parte.qr?.codigoManual ?? '';
      _fecha.text =
          DateFmt.ddmmyyyy(ultimo?.fechaDesde ?? documento.parte.fecha);
      _dias.text = ultimo?.diasAprobados.toString() ?? '';
      _medico.text = ultimo?.medicoNombre ?? '';
      _matricula.text = ultimo?.medicoMatricula ?? '';
      _motivo.clear();
      setState(() {
        _documento = documento;
        _puedeControlar = permisos[0];
        _puedeAdministrar = permisos[1];
      });
    } catch (error) {
      if (mounted) setState(() => _error = cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guardar() async {
    if (_busy || !_form.currentState!.validate() || !_contrastado) return;
    final documento = _documento!;
    setState(() {
      _busy = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await ref.read(medicosRepoProvider).guardarControl(
            qr: documento.parte.qr!,
            fechaDesde:
                DateFormat('dd/MM/yyyy').parseStrict(_fecha.text.trim()),
            diasAprobados: int.parse(_dias.text.trim()),
            medicoNombre: _medico.text,
            medicoMatricula: _matricula.text,
            versionEsperada: documento.ultimoControl?.version ?? 0,
            motivoRectificacion: _rectificando ? _motivo.text : null,
          );
      if (!mounted) return;
      // Tras una respuesta exitosa bloqueamos otro guardado, incluso si falla
      // la consulta de actualización. Un error de red nunca repite la escritura.
      setState(() {
        _documento = null;
        _rectificando = false;
        _contrastado = false;
      });
      await _buscar(id: documento.parte.id);
      if (mounted) {
        setState(
            () => _mensaje = 'Devolución registrada. Historial conservado.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documento = _documento;
    final ultimo = documento?.ultimoControl;
    final editable = documento != null &&
        !documento.anulado &&
        documento.parte.qr != null &&
        _puedeControlar &&
        (ultimo == null || _rectificando);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Control de devolución'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    readOnly: _busy || widget.parteId != null,
                    decoration: const InputDecoration(
                      labelText: 'Código del parte o contenido del QR',
                      hintText: '0000 0422',
                    ),
                    onSubmitted:
                        _busy ? null : (_) => _buscar(id: widget.parteId),
                    onChanged: (_) => setState(() {
                      _documento = null;
                      _error = null;
                      _mensaje = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => _buscar(id: widget.parteId),
                      icon: const Icon(Icons.search),
                      label: const Text('Consultar parte'),
                    ),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (_mensaje != null) Text(_mensaje!),
                  if (documento != null) ...[
                    const SizedBox(height: 12),
                    Text(documento.parte.empleadoCompleto,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        'Parte N.º ${documento.parte.id} · DNI ${documento.parte.dni}'),
                    Text(
                        '${documento.parte.tipo.label} · ${DateFmt.ddmmyyyy(documento.parte.fecha)}'),
                    if (documento.parte.familiarApellidoNombre != null)
                      Text(
                          'Familiar: ${documento.parte.familiarApellidoNombre}'),
                    const SizedBox(height: 12),
                    Text(documento.anulado
                        ? 'PARTE ANULADO · No admite devolución.'
                        : ultimo == null
                            ? 'Pendiente de devolución'
                            : 'Devolución registrada · ${ultimo.diasAprobados} días aprobados'),
                    if (editable) ...[
                      const SizedBox(height: 12),
                      const Text(
                          'Cargá las fechas, días y médico que figuran en el papel.'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fecha,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                            labelText: 'Inicio (dd/mm/aaaa)'),
                        validator: (value) {
                          try {
                            DateFormat('dd/MM/yyyy').parseStrict(value!.trim());
                            return null;
                          } catch (_) {
                            return 'Ingresá una fecha válida en formato dd/mm/aaaa.';
                          }
                        },
                      ),
                      TextFormField(
                        controller: _dias,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Días corridos aprobados',
                          helperText: 'Ingresá 0 si el papel no aprueba días.',
                        ),
                        validator: (value) {
                          final dias = int.tryParse(value?.trim() ?? '');
                          return dias == null || dias < 0 || dias > 3650
                              ? 'Ingresá una cantidad entera entre 0 y 3650.'
                              : null;
                        },
                      ),
                      TextFormField(
                        controller: _medico,
                        enabled: !_busy,
                        maxLength: 150,
                        decoration: const InputDecoration(
                            labelText: 'Médico del papel'),
                        validator: _requerido,
                      ),
                      TextFormField(
                        controller: _matricula,
                        enabled: !_busy,
                        maxLength: 50,
                        decoration:
                            const InputDecoration(labelText: 'Matrícula'),
                        validator: _requerido,
                      ),
                      if (_rectificando)
                        TextFormField(
                          controller: _motivo,
                          enabled: !_busy,
                          maxLength: 500,
                          decoration: const InputDecoration(
                              labelText: 'Motivo de rectificación'),
                          validator: _requerido,
                        ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _contrastado,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                setState(() => _contrastado = value == true),
                        title: const Text(
                            'Contrasté estos datos con el parte devuelto.'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ] else if (!documento.anulado &&
                        ultimo == null &&
                        !_puedeControlar)
                      const Text(
                          'Para registrar la devolución necesitás el permiso MEDICOS_CONTROL.'),
                    if (ultimo != null &&
                        !documento.anulado &&
                        _puedeControlar &&
                        _puedeAdministrar &&
                        !_rectificando)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _rectificando = true),
                        child:
                            const Text('Rectificar conservando el historial'),
                      ),
                    for (final control in documento.controles) ...[
                      const Divider(),
                      Text(
                          'Registro ${control.version} · ${control.diasAprobados} días'),
                      Text('Desde ${DateFmt.ddmmyyyy(control.fechaDesde)}'
                          '${control.fechaHasta == null ? '' : ' hasta ${DateFmt.ddmmyyyy(control.fechaHasta!)}'}'),
                      Text(
                          '${control.medicoNombre} · Matrícula ${control.medicoMatricula}'),
                      Text(
                          'Registrado: ${DateFormat('dd/MM/yyyy HH:mm').format(control.registradoAt.toLocal())}'),
                      SelectableText('Usuario: ${control.usuarioRegistro}'),
                      if (control.motivoRectificacion != null)
                        Text('Motivo: ${control.motivoRectificacion}'),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cerrar')),
          if (editable)
            FilledButton(
              onPressed: _busy || !_contrastado ? null : _guardar,
              child: Text(_rectificando
                  ? 'Guardar rectificación'
                  : 'Registrar devolución'),
            ),
        ],
      ),
    );
  }

  String? _requerido(String? value) =>
      value == null || value.trim().isEmpty ? 'Completá este dato.' : null;
}
