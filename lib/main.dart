import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';
import 'utils/app_localizations.dart';
import 'providers/theme_provider.dart' show themeProvider, accentColorProvider;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    const ProviderScope(
      child: PassGuardVaultApp(),
    ),
  );
}

class PassGuardVaultApp extends ConsumerWidget {
  const PassGuardVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'PassGuard Vault',
      debugShowCheckedModeBanner: false,
      
      // Theme — rebuilt whenever accent color or mode changes
      theme: AppTheme.buildLightTheme(ref.watch(accentColorProvider)),
      darkTheme: AppTheme.buildDarkTheme(ref.watch(accentColorProvider)),
      themeMode: ref.watch(themeProvider),
      
      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'), // Turkish
        Locale('en', 'US'), // English
        Locale('de', 'DE'), // German
        Locale('fr', 'FR'), // French
        Locale('ar', 'SA'), // Arabic
        Locale('es', 'ES'), // Spanish
        Locale('it', 'IT'), // Italian
        Locale('pt', 'BR'), // Portuguese
        Locale('ru', 'RU'), // Russian
        Locale('ja', 'JP'), // Japanese
        Locale('zh', 'CN'), // Chinese Simplified
        Locale('ko', 'KR'), // Korean
        Locale('nl', 'NL'), // Dutch
      ],
      
      home: const SplashScreen(),
    );
  }
}