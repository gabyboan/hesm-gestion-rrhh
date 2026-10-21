import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/parte_medico.dart';

/// Bandeja de la sesión: se conserva al navegar entre módulos.
final colaImpresionProvider =
    StateNotifierProvider<ColaImpresionController, List<ParteMedico>>(
  (ref) => ColaImpresionController(),
);

class ColaImpresionController extends StateNotifier<List<ParteMedico>> {
  ColaImpresionController() : super(const []);

  void agregar(ParteMedico parte) {
    state = [...state.where((item) => item.id != parte.id), parte];
  }

  void quitar(int id) {
    state = state.where((parte) => parte.id != id).toList();
  }

  void quitarTodos(Iterable<int> ids) {
    final impresos = ids.toSet();
    state = state.where((parte) => !impresos.contains(parte.id)).toList();
  }
}
