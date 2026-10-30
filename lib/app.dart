import 'package:flutter/material.dart';

import 'features/common/welcome.dart';
import 'features/shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class CentsGoApp extends StatelessWidget {
  const CentsGoApp({super.key, required this.state});

  final AppState state;

  /// Debug helpers for QA:
  ///   --dart-define=START_TAB=1          opens the map on launch
  ///   --dart-define=SKIP_ONBOARDING=true skips the welcome screen
  static const int _startTab = int.fromEnvironment('START_TAB', defaultValue: 0);
  static const bool _skipOnboarding = bool.fromEnvironment('SKIP_ONBOARDING');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final brightness = MediaQuery.platformBrightnessOf(context);
        return MaterialApp(
          title: 'CentsGo',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(state.settings.themeMode, brightness),
          home: state.loading
              ? const _BootstrapScreen()
              : (state.error != null
                  ? _ErrorScreen(message: state.error!)
                  : ((state.settings.onboarded || _skipOnboarding)
                      ? Shell(state: state, initialTab: _startTab)
                      : WelcomeScreen(state: state))),
        );
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.brand,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/branding/icon.png', width: 88, height: 88),
            ),
            const SizedBox(height: 20),
            Text(
              'CentsGo',
              style: TextStyle(fontFamily: AppFonts.display, fontSize: 34, color: p.brandOn),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: p.brandOn.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 12),
            Text(
              'Carico gli impianti…',
              style: TextStyle(fontSize: 12.5, color: p.brandOn.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 42, color: p.bad),
              const SizedBox(height: 14),
              Text('Impossibile caricare i dati', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
