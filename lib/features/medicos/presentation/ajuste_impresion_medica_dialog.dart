import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/utils/error_text.dart';
import '../data/ajuste_impresion_medica_repository.dart';
import '../data/parte_medico_printer.dart';
import '../domain/ajuste_impresion_medica.dart';
import '../domain/parte_medico.dart';

class AjusteImpresionMedicaDialog extends StatefulWidget {
  const AjusteImpresionMedicaDialog({super.key, required this.parte});

  final ParteMedico parte;

  @override
  State<AjusteImpresionMedicaDialog> createState() =>
      _AjusteImpresionMedicaDialogState();
}

class _AjusteImpresionMedicaDialogState
    extends State<AjusteImpresionMedicaDialog> {
  final _form = GlobalKey<FormState>();
  final _horizontal = TextEditingController();
  final _vertical = TextEditingController();
  final _repository = const AjusteImpresionMedicaRepository();
  bool _loading = true;
  bool _busy = false;
  bool _loaded = false;
  bool _destinoCargado = false;
  List<Printer> _impresoras = const [];
  Printer? _impresora;
  String? _error;
  String? _resultadoPrueba;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _mostrar(AjusteImpresionMedica ajuste) {
    _horizontal.text = ajuste.horizontalMm.toString().replaceAll('.', ',');
    _vertical.text = ajuste.verticalMm.toString().replaceAll('.', ',');
  }

  Future<void> _cargar() async {
    try {
      final info = await Printing.info();
      if (info.canListPrinters && info.directPrint) {
        _impresoras = await Printing.listPrinters();
        if (_impresoras.isEmpty) {
          throw StateError('No hay impresoras instaladas en este equipo.');
        }
        _impresora = _impresoras.firstWhere(
          (impresora) => impresora.isDefault,
          orElse: () => _impresoras.first,
        );
      }
      _destinoCargado = true;
      await _cargarAjuste();
    } catch (e) {
      _mostrarErrorCarga(e);
    }
  }

  Future<void> _cargarAjuste() async {
    try {
      final ajuste = await _repository.cargar(impresora: _impresora?.url);
      if (!mounted) return;
      setState(() {
        _mostrar(ajuste);
        _loaded = true;
        _loading = false;
      });
    } catch (e) {
      _mostrarErrorCarga(e);
    }
  }

  void _mostrarErrorCarga(Object error) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = 'No se pudo cargar el ajuste: ${cleanError(error)}. '
          '${_destinoCargado ? 'Podés restablecer la calibración inicial.' : 'Podés reintentar la carga.'}';
    });
  }

  Future<void> _seleccionarImpresora(String? url) async {
    if (url == null) return;
    setState(() {
      _impresora = _impresoras.firstWhere((impresora) => impresora.url == url);
      _loaded = false;
      _loading = true;
      _error = null;
      _resultadoPrueba = null;
    });
    await _cargarAjuste();
  }

  double? _numero(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  String? _validar(String? value) {
    final numero = _numero(value);
    if (numero == null || !numero.isFinite) return 'Ingresá un número válido.';
    if (numero.abs() > AjusteImpresionMedica.limiteMm) {
      return 'Ingresá un valor entre -10 y 10 mm.';
    }
    return null;
  }

  AjusteImpresionMedica get _ajuste => AjusteImpresionMedica(
        horizontalMm: _numero(_horizontal.text)!,
        verticalMm: _numero(_vertical.text)!,
      );

  void _mover(TextEditingController controller, double paso) {
    final value = _numero(controller.text);
    if (value == null || !value.isFinite) return;
    final next = (value + paso).clamp(-10.0, 10.0);
    controller.text = next.toStringAsFixed(2).replaceAll('.', ',');
    _form.currentState!.validate();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.guardar(_ajuste, impresora: _impresora?.url);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el ajuste: ${cleanError(e)}';
      });
    }
  }

  Future<void> _probar() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final ajuste = _ajuste;
    final impresora = _impresora;
    setState(() {
      _busy = true;
      _error = null;
      _resultadoPrueba = null;
    });
    try {
      final enviada = await ParteMedicoPrinter.imprimirPrueba(
        widget.parte,
        ajuste: ajuste,
        impresora: impresora,
      );
      if (!mounted) return;
      setState(() => _resultadoPrueba = enviada
          ? 'Prueba enviada: horizontal ${ajuste.horizontalMm} mm; '
              'vertical ${ajuste.verticalMm} mm. '
              'Guardá el ajuste cuando la hoja salga alineada.'
          : 'Prueba cancelada. Podés ajustar y volver a probar.');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo imprimir: ${cleanError(e)}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required String ayuda,
    required IconData menos,
    required IconData mas,
    required String direccionMenos,
    required String direccionMas,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: _loaded && !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              validator: _validar,
              decoration: InputDecoration(
                labelText: label,
                suffixText: 'mm',
                helperText: ayuda,
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Mover 0,1 mm $direccionMenos',
            onPressed:
                _loaded && !_busy ? () => _mover(controller, -0.1) : null,
            icon: Icon(menos),
          ),
          IconButton(
            tooltip: 'Mover 0,1 mm $direccionMas',
            onPressed: _loaded && !_busy ? () => _mover(controller, 0.1) : null,
            icon: Icon(mas),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('Ajustar impresión'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Mové todos los textos y tachaduras del parte. '
                      'Estos valores se suman a la calibración inicial '
                      'y se guardan en este equipo. Cada impresora conserva '
                      'su propio ajuste para las próximas impresiones.',
                    ),
                    const SizedBox(height: 20),
                    if (_impresoras.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _impresora?.url,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Impresora a ajustar',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final impresora in _impresoras)
                            DropdownMenuItem(
                              value: impresora.url,
                              child: Text(impresora.name,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged:
                            _loading || _busy ? null : _seleccionarImpresora,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      _campo(
                        controller: _horizontal,
                        label: 'Movimiento horizontal',
                        ayuda: 'Positivo: derecha. Negativo: izquierda.',
                        menos: Icons.arrow_back,
                        mas: Icons.arrow_forward,
                        direccionMenos: 'a la izquierda',
                        direccionMas: 'a la derecha',
                      ),
                      const SizedBox(height: 16),
                      _campo(
                        controller: _vertical,
                        label: 'Movimiento vertical',
                        ayuda: 'Positivo: abajo. Negativo: arriba.',
                        menos: Icons.arrow_upward,
                        mas: Icons.arrow_downward,
                        direccionMenos: 'hacia arriba',
                        direccionMas: 'hacia abajo',
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Colocá el formulario preimpreso para probar. '
                      'La prueba no registra un parte. Se imprime en A4 '
                      'a tamaño real. Guardá el ajuste después de probarlo.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    if (_resultadoPrueba != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(_resultadoPrueba!),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _loaded && !_busy ? _probar : null,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Imprimir prueba'),
                        ),
                        TextButton(
                          onPressed: !_destinoCargado || _loading || _busy
                              ? null
                              : () {
                                  setState(() {
                                    _mostrar(const AjusteImpresionMedica());
                                    _loaded = true;
                                    _error = null;
                                    _resultadoPrueba = null;
                                  });
                                  _form.currentState!.validate();
                                },
                          child: const Text('Restablecer'),
                        ),
                        if (!_loaded && !_loading)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _cargar();
                            },
                            child: const Text('Reintentar'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _loaded && !_busy ? _guardar : null,
              child: Text(_busy ? 'Procesando…' : 'Guardar ajuste'),
            ),
          ],
        ),
      );
}
