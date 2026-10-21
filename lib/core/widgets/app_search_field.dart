import 'dart:async';

import 'package:flutter/material.dart';

/// Shared search input: clear and submit are immediate; typing is debounced.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.labelText,
    required this.onChanged,
    this.initialValue = '',
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String labelText;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final bool autofocus;
  final Duration debounce;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  Timer? _timer;

  void _changed(String value, {bool immediate = false}) {
    _timer?.cancel();
    setState(() {});
    if (immediate || value.trim().isEmpty || widget.debounce == Duration.zero) {
      widget.onChanged(value);
    } else {
      _timer = Timer(widget.debounce, () => widget.onChanged(value));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      onChanged: _changed,
      onSubmitted: (value) => _changed(value, immediate: true),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: 'Combiná palabras en cualquier orden',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                onPressed: () {
                  _controller.clear();
                  _changed('', immediate: true);
                },
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}
