import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/app_translations.dart';
import 'data/repositories/food_repository.dart';
import 'data/services/ai_gateway.dart';
import 'data/services/ai_gateway_adapter.dart';
import 'data/services/database_service.dart';
import 'data/services/external_food_service.dart';
import 'data/services/notification_service.dart';

import 'data/services/image_storage_service.dart';
import 'presentation/cubit/food_log_cubit.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/main_navigator.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/widgets/app_error_boundary.dart';
import 'presentation/widgets/app_error_fallback.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Red global de seguridad: ningún error asíncrono o de framework
  // debe matar la app en silencio.
  FlutterError.onError = (details) {
    // El detalle técnico queda en los logs de desarrollo; la UI solo muestra
    // el fallback recuperable cuando Flutter no puede pintar el árbol.
    AppErrorBoundary.report(details.exception, details.stack ?? StackTrace.empty);
  };
  ErrorWidget.builder = (_) => const AppErrorFallback();

  await runZonedGuarded(() async {
    await _bootstrap();
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

Future<void> _bootstrap() async {
  // El .env es opcional: si falta, la app arranca igual (Ollama/perfil guardado).
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('main: .env no disponible ($e); se continúa sin él');
  }

  final notificationService = NotificationService();
  final prefs = await SharedPreferences.getInstance();

  final bool showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);

  final String languageCode = prefs.getString('language_code') ?? 'es';
  final Locale appLocale = Locale(languageCode);

  // AiGateway se autoconfigura de forma perezosa desde preferencias y
  // (.env). La IA y las notificaciones no deben retrasar el primer frame.
  final databaseService = DatabaseService();
  final imageStorageService = ImageStorageService();

  final externalFoodService = ExternalFoodService();
  final foodRepository = FoodRepository(
    prefs,
    databaseService,
    externalFoodService,
    imageStorageService,
    aiGateway: const AiGatewayAdapter(),
  );

  // Migración one-shot: registro de comidas desde SharedPreferences
  // (food_log_YYYY-MM-DD) a la tabla SQLite food_entries. No debe perderse
  // ninguna comida ya registrada; si falla, se reintenta en el próximo
  // arranque (la marca se escribe al final).
  try {
    await foodRepository.migrateFoodLogFromPrefs();
  } catch (e) {
    debugPrint('main: error migrando food_log a SQLite: $e');
  }

  runApp(
    AppErrorBoundary(
      child: LocaleNotifier(
        initialLocale: appLocale,
        showOnboarding: showOnboarding,
        foodRepository: foodRepository,
      ),
    ),
  );

  // Las tareas nativas y la configuración de IA se ejecutan después del
  // primer frame. Ambas APIs también tienen inicialización perezosa, por lo
  // que abrir una pantalla inmediatamente sigue siendo seguro.
  unawaited(() async {
    try {
      await Future.wait([
        AiGateway.initFromPrefs(),
        notificationService.scheduleSmartNotifications(),
      ]);
    } catch (error) {
      debugPrint('main: error en tareas de fondo: $error');
    }
  }());
}

class LocaleNotifier extends StatefulWidget {
  final Locale initialLocale;
  final bool showOnboarding;
  final FoodRepository foodRepository;

  const LocaleNotifier({
    super.key,
    required this.initialLocale,
    required this.showOnboarding,
    required this.foodRepository,
  });

  static void updateLocale(Locale locale) {
    _LocaleNotifierState.instance?.setLocaleInternal(locale);
  }

  @override
  State<LocaleNotifier> createState() => _LocaleNotifierState();
}

class _LocaleNotifierState extends State<LocaleNotifier> {
  late Locale _locale;
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey();
  static _LocaleNotifierState? _instance;

  static _LocaleNotifierState? get instance => _instance;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _instance = this;
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  /// Único punto de cambio de idioma (persiste y refresca la UI).
  void setLocaleInternal(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    if (mounted) {
      setState(() {
        _locale = locale;
      });
    }
  }

  // Antes había tres métodos idénticos (updateLocale estático, updateLocale de
  // instancia y setLocale); se unifica en setLocaleInternal + el static de arriba.
  void setLocale(Locale locale) => setLocaleInternal(locale);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FoodLogCubit(widget.foodRepository)..loadDailyLog(),
      child: LocaleProvider(
        locale: _locale,
        setLocale: setLocale,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'CalAI',
          locale: _locale,
          localizationsDelegates: [
            AppTranslations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            const Locale('en'),
            const Locale('es'),
          ],
          theme: AppTheme.darkTheme,
          // Una sola app: el MainNavigator (5 pestañas). Antes había un
          // AppSwitcherScreen que bifurcaba en dos modos con dos navegadores.
          home: widget.showOnboarding
              ? const OnboardingScreen()
              : const MainNavigator(),
          routes: {
            '/main': (context) => const MainNavigator(),
            '/home': (context) => const HomeScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/settings': (context) => const ProfileScreen(),
          },
        ),
      ),
    );
  }
}
