import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/suplencias_providers.dart';

class SuplenciasPage extends ConsumerStatefulWidget {
  const SuplenciasPage({super.key});

  @override
  ConsumerState<SuplenciasPage> createState() => _SuplenciasPageState();
}

class _SuplenciasPageState extends ConsumerState<SuplenciasPage> {
  static const columnas = <(String, String)>[
    ('suplente_dni', 'Suplente DNI'),
    ('suplente_apellido', 'Suplente Apellido'),
    ('suplente_nombre', 'Suplente Nombre'),
    ('suplente_servicio', 'Suplente Servicio'),
    ('titular_dni', 'Titular DNI'),
    ('titular_apellido', 'Titular Apellido'),
    ('titular_nombre', 'Titular Nombre'),
    ('titular_servicio', 'Titular Servicio'),
    ('fecha_desde_fmt', 'Desde'),
    ('fecha_hasta_fmt', 'Hasta'),
    ('dias_corridos', 'Días'),
    ('motivo', 'Motivo'),
  ];

  final horizontal = ScrollController();
  final vertical = ScrollController();
  Timer? debounce;
  List<Map<String, dynamic>> filas = const [];
  String buscar = '';
  String orden = 'id';
  bool ascendente = false;
  bool cargando = false;
  bool cargaInicial = false;
  Object? error;

  @override
  void dispose() {
    debounce?.cancel();
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  Future<void> cargar() async {
    if (cargando) return;
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final resultado = await ref.read(suplenciasRepoProvider).listar(
            buscar: buscar,
            ordenarPor: orden,
            ascendente: ascendente,
          );
      if (mounted) setState(() => filas = resultado);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void buscarLuego(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      buscar = value.trim();
      cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(puedeLeerSuplenciasProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('No se pudo validar el permiso: $e')),
          data: (permitido) {
            if (!permitido) {
              return const Center(
                  child: Text('No tenés permiso para ver suplencias.'));
            }
            if (!cargaInicial) {
              cargaInicial = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => cargar());
            }
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                    onChanged: buscarLuego,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por DNI, apellido, servicio o motivo',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  )),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: orden,
                    items: [
                      for (final c in columnas)
                        DropdownMenuItem(
                            value: c.$1, child: Text('Orden: ${c.$2}')),
                      const DropdownMenuItem(
                          value: 'id', child: Text('Orden: ID')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => orden = value);
                      cargar();
                    },
                  ),
                  IconButton(
                    tooltip: ascendente ? 'Ascendente' : 'Descendente',
                    onPressed: () {
                      setState(() => ascendente = !ascendente);
                      cargar();
                    },
                    icon: Icon(
                        ascendente ? Icons.arrow_upward : Icons.arrow_downward),
                  ),
                  IconButton(
                    tooltip: 'Recargar',
                    onPressed: cargando ? null : cargar,
                    icon: const Icon(Icons.refresh),
                  ),
                ]),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('No se pudieron cargar las suplencias: $error'),
                ),
              Expanded(
                  child: cargando && filas.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : Scrollbar(
                          controller: horizontal,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: horizontal,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minWidth: columnas.length * 160),
                              child: Scrollbar(
                                controller: vertical,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: vertical,
                                  child: DataTable(
                                    columns: [
                                      for (final c in columnas)
                                        DataColumn(label: Text(c.$2))
                                    ],
                                    rows: [
                                      for (final fila in filas)
                                        DataRow(cells: [
                                          for (final c in columnas)
                                            DataCell(
                                                Text('${fila[c.$1] ?? ''}')),
                                        ])
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )),
            ]);
          },
        );
  }
}
