import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/date_fmt.dart';
import '../../../../../core/utils/error_text.dart';
import '../../../application/informe_providers.dart';

class InformeRowsTable extends StatelessWidget {
  final AsyncValue<List<InformeRow>> rows;

  const InformeRowsTable({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          const _InformeRow3Cols(
            enf: 'Enfermedad',
            nombre: 'Apellido, Nombre',
            part: 'Particulares',
            trailingSmall: '',
            header: true,
          ),
          Expanded(
            child: rows.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: Text('Error: ${cleanError(e)}'),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Sin resultados'),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final row = items[i];
                    final persona = row.persona;

                    final enfermedad = DateFmt.resumenFechasDdmm(
                      row.enfermedadPorDia,
                    );
                    final particulares = DateFmt.resumenMinutosConFecha(
                      row.particularesPorDia,
                    );

                    return _InformeRow3Cols(
                      enf: enfermedad,
                      nombre: '${persona.apellido}, ${persona.nombre}',
                      part: particulares,
                      trailingSmall:
                          'DNI ${persona.dni} • C${persona.carreraId}',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InformeRow3Cols extends StatelessWidget {
  final String enf;
  final String nombre;
  final String part;
  final String trailingSmall;
  final bool header;

  const _InformeRow3Cols({
    required this.enf,
    required this.nombre,
    required this.part,
    required this.trailingSmall,
    this.header = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colorScheme = Theme.of(context).colorScheme;

        const wEnf = 220.0;
        const wNombre = 320.0;
        final wPart =
            (constraints.maxWidth - wEnf - wNombre).clamp(200.0, 20000.0);

        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              _InformeCell(enf, width: wEnf, bold: header),
              _InformeCell(nombre, width: wNombre, bold: true),
              SizedBox(
                width: wPart,
                child: Row(
                  children: [
                    Expanded(
                      child: _InformeCell(
                        part,
                        width: wPart,
                        bold: header,
                      ),
                    ),
                    if (trailingSmall.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          trailingSmall,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InformeCell extends StatelessWidget {
  final String text;
  final double width;
  final bool bold;

  const _InformeCell(
    this.text, {
    required this.width,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontSize: 13.5,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
