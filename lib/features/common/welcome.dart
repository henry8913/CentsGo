import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.brand, Color.lerp(p.brand, Brand.orangeDeep, 0.85)!],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: p.brandOn,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(Icons.local_gas_station_rounded, size: 54, color: p.brand),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'CentsGo',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 52,
                          height: 1,
                          color: p.brandOn,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Il pieno più conveniente,\nvicino a te.',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: p.brandOn.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const _Bullet(
                        icon: Icons.savings_outlined,
                        title: 'Prezzi ufficiali, ogni giorno',
                        text: 'Oltre 21.000 impianti italiani: benzina, gasolio, GPL, metano e HVO, self e servito.',
                      ),
                      const _Bullet(
                        icon: Icons.map_outlined,
                        title: 'Mappa, lista e viaggio',
                        text: 'Il distributore più economico intorno a te o lungo il percorso, con i servizi sulla mappa.',
                      ),
                      const _Bullet(
                        icon: Icons.directions_car_outlined,
                        title: 'Garage e spese',
                        text: 'Pieno stimato, rifornimenti, consumo reale e scadenze di bollo, assicurazione e revisione.',
                      ),
                      const Spacer(flex: 3),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: state.completeOnboarding,
                          style: FilledButton.styleFrom(
                            backgroundColor: p.brandOn,
                            foregroundColor: p.brand,
                            minimumSize: const Size.fromHeight(58),
                          ),
                          child: const Text('Inizia'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Nessuna registrazione · Dati MIMIT e OpenStreetMap',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: p.brandOn.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.brandOn.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.brandOn.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: p.brandOn, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: p.brandOn, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: p.brandOn.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
