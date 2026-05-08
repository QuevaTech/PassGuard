import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';
import 'utils/app_localizations.dart';
import 'providers/theme_provider.dart'
    show themeProvider, appThemeStyleProvider, accentColorProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: PassGuardVaultApp()));
}

class PassGuardVaultApp extends ConsumerWidget {
  const PassGuardVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style  = ref.watch(appThemeStyleProvider);
    final accent = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'PassGuard Vault',
      debugShowCheckedModeBanner: false,

      theme:     AppTheme.buildTheme(style, Brightness.light, accent: accent),
      darkTheme: AppTheme.buildTheme(style, Brightness.dark,  accent: accent),
      themeMode: ref.watch(themeProvider),

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
        Locale('de', 'DE'),
        Locale('fr', 'FR'),
        Locale('ar', 'SA'),
        Locale('es', 'ES'),
        Locale('it', 'IT'),
        Locale('pt', 'BR'),
        Locale('ru', 'RU'),
        Locale('ja', 'JP'),
        Locale('zh', 'CN'),
        Locale('ko', 'KR'),
        Locale('nl', 'NL'),
      ],

      home: const SplashScreen(),
    );
  }
}
