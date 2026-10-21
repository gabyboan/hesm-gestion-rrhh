import 'dart:io';

import 'package:app_horas/app/theme/theme_mode_provider.dart';
import 'package:app_horas/core/supabase/supabase_provider.dart';
import 'package:app_horas/core/utils/search_query.dart';
import 'package:app_horas/features/auth/application/auth_providers.dart';
import 'package:app_horas/features/auth/application/current_roles_provider.dart';
import 'package:app_horas/features/auth/data/auth_repository.dart';
import 'package:app_horas/features/francos/application/francos_providers.dart';
import 'package:app_horas/features/francos/domain/franco_movimiento.dart';
import 'package:app_horas/features/francos/domain/franco_persona.dart';
import 'package:app_horas/features/horas/application/horas_providers.dart';
import 'package:app_horas/features/horas/domain/hora_registro.dart';
import 'package:app_horas/features/horas/domain/persona.dart';
import 'package:app_horas/features/imprevistos/application/imprevistos_providers.dart';
import 'package:app_horas/features/imprevistos/domain/imprevisto_persona.dart';
import 'package:app_horas/features/imprevistos/domain/imprevisto_registro.dart';
import 'package:app_horas/features/medicos/application/cola_impresion_provider.dart';
import 'package:app_horas/features/medicos/application/medicos_providers.dart';
import 'package:app_horas/features/medicos/domain/medico_domicilio.dart';
import 'package:app_horas/features/medicos/domain/medico_persona.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/preferences/application/user_preferences_providers.dart';
import 'package:app_horas/features/preferences/data/user_preferences_repository.dart';
import 'package:app_horas/features/preferences/domain/current_user_profile.dart';
import 'package:app_horas/features/preferences/domain/user_preferences.dart';
import 'package:app_horas/features/shell/presentation/main_shell.dart';
import 'package:app_horas/features/suplencias/application/suplencias_providers.dart';
import 'package:app_horas/features/suplencias/data/suplencias_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Separate entry point: the normal application never imports this demo.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = DemoNetworkDisabled();
  // Isolate printer calibration from the normal app's local preferences.
  SharedPreferences.setPrefix('hesm_demo.');
  runApp(const DemoApp());
}

class DemoNetworkDisabled extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw UnsupportedError('La demo usa datos ficticios sin conexión.');
}

final demoDate = DateTime(2026, 10, 21);
final demoPeriod = DateTime(2026, 10);
const _readOnlyMessage =
    'Demo de consulta: los registros no se pueden guardar ni eliminar.';
const _demoAddress = MedicoDomicilio(
  calle: 'Calle ficticia',
  numero: '100',
  torre: 'A',
  localidad: 'Localidad de ejemplo',
  provincia: 'Provincia de ejemplo',
);
final _people = [
  for (var i = 1; i <= 3; i++)
    Persona(
        apellido: 'DEMO',
        nombre: 'Persona $i',
        dni: 1000 + i,
        carreraId: 1,
        carrera: 'Carrera de ejemplo'),
];
final _hours = [
  for (final person in _people)
    for (var i = 0; i < 3; i++)
      HoraRegistro(
          id: person.dni * 10 + i,
          dni: person.dni,
          carreraId: person.carreraId,
          fecha: DateTime(2026, 10, 12 + 3 * i),
          periodo: demoPeriod,
          tipo: i == 2 ? 'OFICIAL' : 'PARTICULAR',
          minutos: 60 + 30 * i,
          minutosAplicados: 60 + 30 * i,
          minutosExcedidos: 0,
          excedido: false,
          createdAt: DateTime(2026, 10, 12 + 3 * i, 9, 30),
          usuarioCargaNombre: 'Cuenta',
          usuarioCargaApellido: 'DEMO'),
];
final _parts = [
  for (var i = 1; i <= 3; i++)
    ParteMedico(
        id: i,
        dni: 1000 + i,
        fecha: demoDate,
        tipo: i == 1
            ? TipoParteMedico.consultorio
            : i == 2
                ? TipoParteMedico.domicilio
                : TipoParteMedico.domicilioFamiliar,
        empleadoApellido: 'DEMO',
        empleadoNombre: 'Persona $i',
        empleadoLegajo: i == 2 ? null : i,
        familiarApellidoNombre: i == 3 ? 'DEMO, Familiar' : null,
        familiarDni: i == 3 ? 1004 : null,
        familiarEdad: i == 3 ? 0 : null,
        familiarEdadMeses: i == 3 ? 6 : null,
        familiarParentesco: i == 3 ? 'Hijo/a' : null,
        esArt: i == 2,
        domicilio: i == 1 ? null : _demoAddress,
        aclaracionFechaTurno: 'Ejemplo ficticio - turno mañana'),
];

class _DemoPreferences implements UserPreferencesRepository {
  UserPreferences value = UserPreferences.defaults;
  @override
  Future<UserPreferences> fetch(String userId) async => value;
  @override
  Future<void> save(
          {required String userId,
          required UserPreferences preferences}) async =>
      value = preferences;
  @override
  Future<CurrentUserProfile?> fetchCurrentProfile() async =>
      const CurrentUserProfile(apellido: 'DEMO', nombre: 'Cuenta');
}

class _DemoAuth implements AuthRepository {
  _DemoAuth(this.reset);
  final VoidCallback reset;
  @override
  Future<void> signOut() async => reset();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('La demo no inicia sesiones de usuario.');
}

class _ReadOnlyCargar extends CargarHoraController {
  @override
  Future<void> submit() async => throw UnsupportedError(_readOnlyMessage);
}

class _ReadOnlyBorrar extends BorrarHoraController {
  @override
  Future<bool> borrar(int id) async => throw UnsupportedError(_readOnlyMessage);
}

class _DemoSuplencias implements SuplenciasRepository {
  @override
  Future<List<Map<String, dynamic>>> listar(
      {String buscar = '',
      String ordenarPor = 'id',
      bool ascendente = false}) async {
    final rows = [
      for (var i = 1; i <= 3; i++)
        {
          'id': i,
          'suplente_dni': 1000 + i,
          'suplente_apellido': 'DEMO',
          'suplente_nombre': 'Persona $i',
          'suplente_servicio': 'Servicio de ejemplo',
          'titular_dni': 1010 + i,
          'titular_apellido': 'DEMO',
          'titular_nombre': 'Titular $i',
          'titular_servicio': 'Servicio de ejemplo',
          'fecha_desde_fmt': '21/10/2026',
          'fecha_hasta_fmt': '23/10/2026',
          'dias_corridos': 3,
          'motivo': 'Cobertura ficticia',
        },
    ].where((row) => SearchQuery(buscar).matches(row.values)).toList();
    rows.sort((a, b) {
      final av = a[ordenarPor], bv = b[ordenarPor];
      final comparison =
          av is int && bv is int ? av.compareTo(bv) : '$av'.compareTo('$bv');
      return ascendente ? comparison : -comparison;
    });
    return rows;
  }
}

/// One container per demo run, with no session or live data dependencies.
class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  int generation = 0;
  @override
  Widget build(BuildContext context) => ProviderScope(
        key: ValueKey(generation),
        overrides: [
          supabaseClientProvider.overrideWith(
              (ref) => throw StateError('La demo no se conecta a Supabase.')),
          authRepoProvider.overrideWith(
              (ref) => _DemoAuth(() => setState(() => generation++))),
          currentRolesProvider.overrideWith(
              (ref) async => const CurrentRoles({'HORAS_LECTURA'})),
          userPreferencesRepositoryProvider
              .overrideWith((ref) => _DemoPreferences()),
          userPreferencesProvider.overrideWith((ref) =>
              ref.watch(userPreferencesRepositoryProvider).fetch('demo')),
          currentUserProfileProvider.overrideWith((ref) => ref
              .watch(userPreferencesRepositoryProvider)
              .fetchCurrentProfile()),
          userPreferencesControllerProvider
              .overrideWith((ref) => UserPreferencesController(
                    repository: ref.watch(userPreferencesRepositoryProvider),
                    currentUserId: () => 'demo',
                    applyTheme: (theme) =>
                        ref.read(themeModeProvider.notifier).state = theme,
                    configureIdleTimeout: (_) {},
                    invalidatePreferences: () =>
                        ref.invalidate(userPreferencesProvider),
                  )),
          listadoProvider.overrideWith((ref) async => _people),
          listadoOficialesProvider.overrideWith((ref) async => _people),
          fechaProvider.overrideWith((ref) => demoDate),
          periodoProvider.overrideWith((ref) => demoPeriod),
          registrosProvider.overrideWith((ref) async {
            final person = ref.watch(selectedPersonaProvider);
            final period = ref.watch(periodoProvider);
            return _hours
                .where((row) =>
                    row.personaKey == person?.key && row.periodo == period)
                .toList();
          }),
          registrosPeriodoProvider.overrideWith((ref) async {
            final period = ref.watch(periodoProvider);
            return _hours.where((row) => row.periodo == period).toList();
          }),
          periodosConRegistrosProvider
              .overrideWith((ref) async => {demoPeriod}),
          cargarHoraControllerProvider.overrideWith(_ReadOnlyCargar.new),
          borrarHoraControllerProvider.overrideWith(_ReadOnlyBorrar.new),
          puedeLeerFrancosProvider.overrideWith((ref) async => true),
          puedeUsarBancoFrancosProvider.overrideWith((ref) async => false),
          puedeAdministrarBancoFrancosProvider
              .overrideWith((ref) async => false),
          francosListadoProvider.overrideWith((ref) async {
            final query = SearchQuery(ref.watch(francosSearchProvider));
            return [
              for (var i = 1; i <= 3; i++)
                FrancoPersona(
                    dni: 1000 + i,
                    apellido: 'DEMO',
                    nombre: 'Persona $i',
                    carreraId: 1,
                    carrera: 'Carrera de ejemplo',
                    saldoMinutos: 600 - 60 * i,
                    tieneHorasCargadas: true),
            ]
                .where((p) =>
                    query.matches([p.dni, p.apellido, p.nombre, p.carrera]))
                .toList();
          }),
          francosMovimientosProvider.overrideWith((ref) async {
            final person = ref.watch(selectedFrancoPersonaProvider);
            if (person == null) return [];
            return [
              FrancoMovimiento(
                  id: person.dni,
                  dni: person.dni,
                  carreraId: 1,
                  fecha: demoDate,
                  periodo: demoPeriod,
                  minutos: 60,
                  motivo: 'Franco de ejemplo',
                  observacion: 'Registro ficticio',
                  usuarioCarga: 'demo',
                  usuarioCargaNombre: 'Cuenta',
                  usuarioCargaApellido: 'DEMO',
                  usuarioModifica: '',
                  createdAt: demoDate,
                  updatedAt: demoDate)
            ];
          }),
          puedeLeerImprevistosProvider.overrideWith((ref) async => true),
          puedeCargarImprevistosProvider.overrideWith((ref) async => false),
          puedeAdministrarImprevistosProvider
              .overrideWith((ref) async => false),
          imprevistosAnioProvider.overrideWith((ref) => 2026),
          imprevistosListadoProvider.overrideWith((ref) async {
            final query = SearchQuery(ref.watch(imprevistosSearchProvider));
            return [
              for (var i = 1; i <= 3; i++)
                ImprevistoPersona(
                    dni: 1000 + i,
                    apellido: 'DEMO',
                    nombre: 'Persona $i',
                    carreraId: 1,
                    carrera: 'Carrera de ejemplo',
                    usados: 1,
                    restantes: 5),
            ]
                .where((p) =>
                    query.matches([p.dni, p.apellido, p.nombre, p.carrera]))
                .toList();
          }),
          imprevistosRegistrosProvider.overrideWith((ref) async {
            final person = ref.watch(selectedImprevistoPersonaProvider);
            if (person == null || ref.watch(imprevistosAnioProvider) != 2026) {
              return [];
            }
            return [
              ImprevistoRegistro(
                  id: person.dni,
                  dni: person.dni,
                  carreraId: 1,
                  fecha: demoDate,
                  anio: 2026,
                  observacion: 'Registro ficticio',
                  numeroOrden: 1,
                  createdAt: demoDate)
            ];
          }),
          puedeLeerMedicosProvider.overrideWith((ref) async => true),
          puedeCrearMedicosProvider.overrideWith((ref) async => false),
          puedeAdministrarMedicosProvider.overrideWith((ref) async => false),
          medicosPersonasProvider.overrideWith((ref) async {
            final query = SearchQuery(ref.watch(medicosSearchProvider));
            return [
              for (var i = 1; i <= 3; i++)
                MedicoPersona(
                    dni: 1000 + i,
                    apellido: 'DEMO',
                    nombre: 'Persona $i',
                    legajo: i == 2 ? null : i),
            ]
                .where((p) =>
                    query.matches([p.dni, p.apellido, p.nombre, p.legajo]))
                .toList();
          }),
          medicosDomicilioProvider
              .overrideWith((ref, dni) async => _demoAddress),
          medicosFamiliaresProvider.overrideWith((ref, dni) async => []),
          partesMedicosProvider.overrideWith((ref) async {
            final query = SearchQuery(ref.watch(partesMedicosSearchProvider));
            return _parts
                .where((p) => query.matches([
                      p.dni,
                      p.descripcionRegistro,
                      p.empleadoLegajo,
                      p.familiarDni
                    ]))
                .toList();
          }),
          colaImpresionProvider
              .overrideWith((ref) => ColaImpresionController()),
          puedeLeerSuplenciasProvider.overrideWith((ref) async => true),
          suplenciasRepoProvider.overrideWith((ref) => _DemoSuplencias()),
        ],
        child: const _DemoMaterialApp(),
      );
}

class _DemoMaterialApp extends ConsumerWidget {
  const _DemoMaterialApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'HESM - Demostración',
        debugShowCheckedModeBanner: false,
        themeMode: ref.watch(themeModeProvider),
        theme: ThemeData(
            useMaterial3: true, colorSchemeSeed: const Color(0xFF4F46E5)),
        darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF4F46E5)),
        locale: const Locale('es', 'AR'),
        supportedLocales: const [Locale('es', 'AR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        builder: (context, child) => Column(children: [
          Material(
              color: const Color(0xFF045E63),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'DEMOSTRACIÓN · DATOS FICTICIOS · SOLO CONSULTA\n'
                  'Sin sesión de usuario. «Salir» reinicia la demo. Solo imprimir con fines de prueba.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white),
                ),
              )),
          Expanded(child: child!),
        ]),
        home: const MainShell(),
      );
}
