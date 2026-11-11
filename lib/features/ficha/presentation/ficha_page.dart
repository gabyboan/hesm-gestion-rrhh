import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/widgets/app_search_field.dart';
import '../application/ficha_providers.dart';
import '../domain/ficha_persona.dart';
import '../domain/ficha_resumen.dart';
import 'ficha_vista_panel.dart';

class FichaPage extends ConsumerStatefulWidget {
  const FichaPage({super.key});
  @override
  ConsumerState<FichaPage> createState() => _FichaPageState();
}

class _FichaPageState extends ConsumerState<FichaPage> {
  String _buscar = '';
  FichaPersona? _persona;
  int _anio = DateTime.now().year;
  bool _incluirAnuladas = false;

  @override
  Widget build(BuildContext context) {
    return ref.watch(puedeLeerFichaProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text(
                  'No se pudieron verificar los permisos: ${cleanError(e)}')),
          data: (puedeLeer) {
            if (!puedeLeer) {
              return const Center(
                  child: Text('Sin permiso para consultar fichas.'));
            }
            return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: AppSearchField(
                            labelText:
                                'Buscar persona por nombre, DNI o legajo',
                            onChanged: (value) =>
                                setState(() => _buscar = value))),
                    const SizedBox(width: 12),
                    SizedBox(
                        width: 125,
                        child: DropdownButtonFormField<int>(
                          initialValue: _anio,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Año', border: OutlineInputBorder()),
                          items: [
                            for (var y = DateTime.now().year + 2;
                                y >= 2026;
                                y--)
                              DropdownMenuItem(value: y, child: Text('$y'))
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _anio = value);
                          },
                        )),
                    IconButton(
                        tooltip: 'Actualizar ficha',
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          ref.invalidate(puedeLeerFichaProvider);
                          ref.invalidate(fichaPersonasProvider);
                          ref.invalidate(fichaLicenciasProvider);
                          ref.invalidate(fichaLicenciasAcumuladasProvider);
                        }),
                  ]),
                  const SizedBox(height: 16),
                  Expanded(child: LayoutBuilder(builder: (ctx, bounds) {
                    final personas = _personas();
                    var actual = _persona;
                    for (final persona in ref
                            .watch(fichaPersonasProvider(_buscar))
                            .valueOrNull ??
                        const <FichaPersona>[]) {
                      if (persona.dni == _persona?.dni) {
                        actual = persona;
                        break;
                      }
                    }
                    final detalle = actual == null
                        ? const Center(
                            child: Text(
                                'Seleccioná una persona para ver su ficha.'))
                        : _detalle(actual);
                    if (bounds.maxWidth < 850) {
                      return Column(children: [
                        SizedBox(height: 180, child: personas),
                        const Divider(),
                        Expanded(child: detalle)
                      ]);
                    }
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 320, child: personas),
                          const VerticalDivider(width: 24),
                          Expanded(child: detalle),
                        ]);
                  })),
                ]));
          },
        );
  }

  Widget _personas() => ref.watch(fichaPersonasProvider(_buscar)).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(cleanError(e))),
        data: (personas) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(personas.length == 100
              ? 'Primeros 100 resultados. Refiná la búsqueda.'
              : '${personas.length} personas'),
          const SizedBox(height: 8),
          Expanded(
              child: personas.isEmpty
                  ? const Center(child: Text('No se encontraron personas.'))
                  : ListView.builder(
                      itemCount: personas.length,
                      itemBuilder: (ctx, i) {
                        final p = personas[i];
                        return ListTile(
                            selected: _persona?.dni == p.dni,
                            title: Text(p.nombre),
                            subtitle: Text(
                                'DNI ${p.dni}${p.legajo == null ? '' : ' · Legajo ${p.legajo}'}'),
                            onTap: () => setState(() => _persona = p));
                      },
                    )),
        ]),
      );

  Widget _detalle(FichaPersona persona) {
    return DefaultTabController(
      key: ValueKey(persona.dni),
      length: 2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(persona.nombre, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        SelectableText(
            'DNI ${persona.dni} · ${persona.activo ? 'Activo' : 'Inactivo'}'),
        const TabBar(
            tabs: [Tab(text: 'Planilla'), Tab(text: 'Datos e historial')]),
        const SizedBox(height: 12),
        Expanded(
            child: TabBarView(children: [
          FichaVistaPanel(persona: persona, anio: _anio),
          _historial(persona),
        ])),
      ]),
    );
  }

  Widget _historial(FichaPersona persona) {
    final consulta = (dni: persona.dni, anio: _anio);
    return ref.watch(fichaLicenciasProvider(consulta)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text('No se pudo cargar la ficha: ${cleanError(e)}')),
          data: (all) {
            final resumen = resumirLicencias(all, _anio);
            final cantidad =
                resumen.fold<int>(0, (total, tipo) => total + tipo.registros);
            final dias =
                resumen.fold<int>(0, (total, tipo) => total + tipo.dias);
            final rows =
                all.where((r) => _incluirAnuladas || !r.anulado).toList();
            return CustomScrollView(
                key: ValueKey('${persona.dni}-$_anio'),
                slivers: [
                  SliverToBoxAdapter(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Datos laborales actuales',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Wrap(spacing: 24, runSpacing: 8, children: [
                          _dato('Legajo', persona.legajo?.toString() ?? ''),
                          _dato('Número de reloj',
                              persona.reloj?.toString() ?? ''),
                          _dato(
                              'Fecha de ingreso',
                              persona.fechaIngreso == null
                                  ? ''
                                  : DateFmt.ddmmyyyy(persona.fechaIngreso!)),
                          _dato('Carrera', persona.carrera),
                          _dato('Situación de revista', persona.situacion),
                          _dato('Función', persona.funcion),
                        ]),
                        const Divider(height: 32),
                        Text('Licencias · $_anio',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          Chip(label: Text('$cantidad licencias registradas')),
                          Chip(label: Text('$dias días en $_anio')),
                        ]),
                        const Text(
                            'Los totales excluyen anulaciones y cuentan solo los días dentro del año seleccionado.'),
                        if (resumen.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(columns: const [
                                  DataColumn(label: Text('Tipo de licencia')),
                                  DataColumn(
                                      label: Text('Registros'), numeric: true),
                                  DataColumn(
                                      label: Text('Días del año'),
                                      numeric: true),
                                ], rows: [
                                  for (final tipo in resumen)
                                    DataRow(cells: [
                                      DataCell(Text(tipo.tipo)),
                                      DataCell(Text('${tipo.registros}')),
                                      DataCell(Text('${tipo.dias}')),
                                    ])
                                ])),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                            spacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('Historial',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              FilterChip(
                                  label: const Text('Incluir anuladas'),
                                  selected: _incluirAnuladas,
                                  onSelected: (value) =>
                                      setState(() => _incluirAnuladas = value)),
                            ]),
                        const Text(
                            'Las cargas y correcciones se realizan desde Licencias; los imprevistos, desde Imprevistos.'),
                        const SizedBox(height: 8),
                        if (rows.isEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                  'No hay licencias registradas para esta persona en el año seleccionado.')),
                      ])),
                  SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (ctx, i) {
                        final r = rows[i];
                        return Card(
                            color: r.documentacionPendiente
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                : null,
                            child: ExpansionTile(
                              title: Text(r.etiqueta),
                              subtitle: Text(
                                  '${DateFmt.ddmmyyyy(r.desde)} al ${DateFmt.ddmmyyyy(r.hasta)} · ${r.dias} ${r.unidadDias}${r.anulado ? ' · Anulada' : ''}'),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (r.documentacionPendiente)
                                  const Text('Documentación pendiente',
                                      style: TextStyle(color: Colors.grey)),
                                if (r.esImprevisto)
                                  const Text('Origen: Imprevistos'),
                                if (r.cantidadFicha?.isNotEmpty == true)
                                  Text('Cantidad en ficha: ${r.cantidadFicha}'),
                                if (r.dniFamiliar != null)
                                  Text('DNI del familiar: ${r.dniFamiliar}'),
                                if (r.numeroOrden != null)
                                  Text('Número de orden: ${r.numeroOrden}'),
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: SelectableText(
                                        r.observacion?.isNotEmpty == true
                                            ? r.observacion!
                                            : 'Sin observaciones.'))
                              ],
                            ));
                      }),
                ]);
          },
        );
  }

  Widget _dato(String label, String valor) => SizedBox(
      width: 230,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(valor.isEmpty ? 'Sin dato' : valor),
      ]));
}
