class CurrentUserProfile {
  final String apellido;
  final String nombre;

  const CurrentUserProfile({
    required this.apellido,
    required this.nombre,
  });

  String get saludo {
    final lastName = apellido.trim();
    final firstNameParts = nombre.trim().split(RegExp(r'\s+'));
    final firstName = firstNameParts.isEmpty ? '' : firstNameParts.first;

    final nameParts = <String>[
      if (lastName.isNotEmpty) lastName,
      if (firstName.isNotEmpty) firstName,
    ];

    return nameParts.isEmpty
        ? 'Bienvenido'
        : 'Bienvenido, ${nameParts.join(' ')}';
  }

  factory CurrentUserProfile.fromJson(Map<String, dynamic> json) {
    return CurrentUserProfile(
      apellido: json['apellido']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
    );
  }
}
