import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/settings.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fuel_bar.dart';
import '../../widgets/ui.dart';
import '../common/place_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final s = state.settings;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              const SectionTitle('Aspetto'),
              _Card(
                child: Column(
                  children: [
                    _ThemeOption(
                      label: 'Sistema',
                      subtitle: 'Segue il tema del dispositivo',
                      mode: AppThemeMode.system,
                      current: s.themeMode,
                      onTap: () => state.setThemeMode(AppThemeMode.system),
                    ),
                    _ThemeOption(
                      label: 'Chiaro',
                      subtitle: 'Bianco, come la mappa di giorno',
                      mode: AppThemeMode.light,
                      current: s.themeMode,
                      onTap: () => state.setThemeMode(AppThemeMode.light),
                    ),
                    _ThemeOption(
                      label: 'Scuro',
                      subtitle: 'Grigio antracite',
                      mode: AppThemeMode.dark,
                      current: s.themeMode,
                      onTap: () => state.setThemeMode(AppThemeMode.dark),
                    ),
                    _ThemeOption(
                      label: 'Nero AMOLED',
                      subtitle: 'Nero puro, risparmia batteria',
                      mode: AppThemeMode.amoled,
                      current: s.themeMode,
                      onTap: () => state.setThemeMode(AppThemeMode.amoled),
                      last: true,
                    ),
                  ],
                ),
              ),
              const SectionTitle('Ricerca e prezzi'),
              _Card(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(fuelIcon(s.fuel), color: p.brand),
                      title: const Text('Carburante predefinito'),
                      subtitle: Text(s.fuel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickFuel(context),
                    ),
                    Divider(color: p.border, height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: s.selfService,
                      onChanged: state.setSelfService,
                      title: const Text('Prezzo self service'),
                      subtitle: const Text('Disattiva per confrontare il servito'),
                    ),
                    Divider(color: p.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.radar, color: p.brand),
                      title: const Text('Raggio di ricerca'),
                      subtitle: Text('${s.radiusKm.round()} km'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickRadius(context),
                    ),
                    Divider(color: p.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.local_offer_outlined, color: p.brand),
                      title: const Text('Filtro marchio'),
                      subtitle: Text(s.brand ?? 'Nessun filtro'),
                      trailing: s.brand == null
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Rimuovi filtro',
                              onPressed: () => state.setBrand(null),
                            ),
                      onTap: () => _pickBrand(context),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Posizione'),
              _Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: s.followGps,
                      onChanged: (v) {
                        if (v) {
                          state.useGps();
                        } else {
                          state.updateSettings(s.copyWith(followGps: false));
                        }
                      },
                      title: const Text('Segui la posizione GPS'),
                      subtitle: Text(
                        s.followGps
                            ? 'L\'app parte dalla tua posizione'
                            : 'L\'app parte dalla zona scelta qui sotto',
                      ),
                    ),
                    Divider(color: p.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.place_outlined, color: p.brand),
                      title: const Text('Zona predefinita'),
                      subtitle: Text(state.gpsPosition != null && s.followGps ? 'GPS attivo' : state.centerLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final place = await pickPlace(context, state, title: 'Zona predefinita');
                        if (place != null) state.setPlace(place);
                      },
                    ),
                    if (state.permissionDenied)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InfoBanner(
                          text: state.permissionPermanentlyDenied
                              ? 'Accesso alla posizione negato. Riattivalo dalle impostazioni di sistema.'
                              : 'Posizione non disponibile su questo dispositivo: usa la zona predefinita.',
                          icon: Icons.location_off_outlined,
                          color: p.warn,
                          action: TextButton(
                            onPressed: () => state.useGps(),
                            child: const Text('Riprova'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SectionTitle('Dati'),
              _Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: state.autoSync,
                      onChanged: state.setAutoSync,
                      title: const Text('Prezzi sempre aggiornati'),
                      subtitle: const Text('Scarica i dati ufficiali MIMIT in automatico'),
                    ),
                    Divider(color: p.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.storage_outlined, color: p.brand),
                      title: Text(state.dataIsDownloaded ? 'Dati scaricati' : 'Dati inclusi nell\'app'),
                      subtitle: Text(
                        'Prezzi del ${state.catalog.extractionDate} · ${Fmt.count(state.catalog.stations.length)} impianti',
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                    Divider(color: p.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: state.syncing
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: p.brand),
                            )
                          : Icon(Icons.cloud_download_outlined, color: p.brand),
                      title: Text(state.syncing ? 'Aggiornamento in corso…' : 'Aggiorna ora'),
                      subtitle: Text(_syncSubtitle(state)),
                      trailing: state.syncing
                          ? Text(
                              '${(state.syncProgress * 100).round()}%',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.brand),
                            )
                          : const Icon(Icons.refresh),
                      onTap: state.syncing ? null : () => state.syncPrices(force: true),
                    ),
                    Divider(color: p.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline, color: p.bad),
                      title: Text('Azzera dati app', style: TextStyle(color: p.bad)),
                      subtitle: const Text('Preferiti, garage, rifornimenti e storico'),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Azzerare tutti i dati?'),
                            content: const Text('L\'operazione non può essere annullata.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Azzera')),
                            ],
                          ),
                        );
                        if (ok == true) await state.resetAll();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Card(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline, color: p.brand),
                  title: const Text('Informazioni e licenze'),
                  subtitle: const Text('Fonti dei dati, marchi e note legali'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'CentsGo 0.1.0 · dati MIMIT ${state.catalog.extractionDate}',
                  style: TextStyle(fontSize: 11.5, color: p.muted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickFuel(BuildContext context) async {
    final selected = await showAppSheet<String>(
      context,
      heightFactor: 0.5,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const SheetTitle('Carburante predefinito'),
          for (final fuel in Fuels.all)
            ListTile(
              leading: Icon(fuelIcon(fuel), color: context.palette.brand),
              title: Text(fuel),
              trailing: state.settings.fuel == fuel ? Icon(Icons.check, color: context.palette.brand) : null,
              onTap: () => Navigator.pop(context, fuel),
            ),
        ],
      ),
    );
    if (selected != null) state.setFuel(selected);
  }

  Future<void> _pickBrand(BuildContext context) async {
    final selected = await showAppSheet<String>(
      context,
      heightFactor: 0.8,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const SheetTitle('Filtro marchio', subtitle: 'Mostra solo i distributori di un marchio'),
          for (final brand in state.catalog.topBrands)
            ListTile(
              leading: BrandBadge(letter: brand.isEmpty ? '?' : brand.substring(0, 1).toUpperCase(), size: 34),
              title: Text(brand),
              trailing: state.settings.brand == brand ? Icon(Icons.check, color: context.palette.brand) : null,
              onTap: () => Navigator.pop(context, brand),
            ),
        ],
      ),
    );
    if (selected != null) state.setBrand(selected);
  }

  Future<void> _pickRadius(BuildContext context) async {
    var value = state.settings.radiusKm;
    final result = await showAppSheet<double>(
      context,
      heightFactor: 0.4,
      child: StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetTitle('Raggio di ricerca'),
              Text('${value.round()} km',
                  style: Money.style(context.palette, size: 32, color: context.palette.brand)),
              Slider(
                value: value,
                min: 1,
                max: 60,
                divisions: 59,
                onChanged: (v) => setLocal(() => value = v),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, value),
                child: const Text('Applica'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) state.setRadius(result);
  }
}

String _syncSubtitle(AppState state) {
  if (state.syncError != null) return state.syncError!;
  final last = state.lastSync;
  if (last == null) return 'Mai aggiornato da quando hai installato l\'app';
  final diff = DateTime.now().difference(last);
  if (diff.inMinutes < 2) return 'Aggiornato adesso';
  if (diff.inMinutes < 60) return 'Aggiornato ${diff.inMinutes} minuti fa';
  if (diff.inHours < 24) return 'Aggiornato ${diff.inHours} ore fa';
  return 'Aggiornato ${Fmt.date(last)} alle ${Fmt.time(last)}';
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: child,
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.subtitle,
    required this.mode,
    required this.current,
    required this.onTap,
    this.last = false,
  });

  final String label;
  final String subtitle;
  final AppThemeMode mode;
  final AppThemeMode current;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: current == mode
              ? Icon(Icons.check_circle, color: p.brand, size: 20)
              : Icon(Icons.circle_outlined, color: p.border, size: 20),
          onTap: onTap,
        ),
        if (!last) Divider(color: p.border, height: 1),
      ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Informazioni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: p.brand, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.local_gas_station, color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('CentsGo', style: TextStyle(fontFamily: AppFonts.display, fontSize: 30, color: p.ink)),
          ),
          Center(
            child: Text(
              'Il pieno più conveniente, vicino a te.',
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Fonti dei dati'),
          _Source(
            title: 'MIMIT — Osservaprezzi carburanti',
            body: 'Prezzi e anagrafica degli impianti italiani, open data pubblicati quotidianamente dal Ministero '
                'delle Imprese e del Made in Italy. Licenza IODL 2.0, attribuzione obbligatoria.',
          ),
          _Source(
            title: 'OpenStreetMap',
            body: 'Zone ZTL, officine, autolavaggi, gommisti e colonnine elettriche derivano da OpenStreetMap '
                '(© OpenStreetMap contributors, ODbL). Tile della mappa servite da openstreetmap.org.',
          ),
          _Source(
            title: 'Tariffe di ricarica',
            body: 'Le tariffe EV sono stime per classe di potenza (AC < 50 kW, DC 50-149 kW, HPC ≥ 150 kW) basate su '
                'un listino locale; il prezzo effettivo dipende dall\'operatore e dall\'abbonamento.',
          ),
          _Source(
            title: 'Font',
            body: 'Plus Jakarta Sans, Archivo Black e IBM Plex Mono, distribuiti con SIL Open Font License.',
          ),
          const SizedBox(height: 18),
          const InfoBanner(
            text: 'CentsGo è un progetto indipendente e non è affiliato ai marchi citati. '
                'Verifica sempre il prezzo esposto in impianto: i dati possono essere incompleti o non aggiornati.',
            icon: Icons.gavel_outlined,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'CentsGo',
              applicationVersion: '0.1.0',
              applicationLegalese: 'Dati MIMIT (IODL 2.0) e OpenStreetMap (ODbL).',
            ),
            icon: const Icon(Icons.article_outlined),
            label: const Text('Licenze open source'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: p.brand,
              side: BorderSide(color: p.brand),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Source extends StatelessWidget {
  const _Source({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(fontSize: 12.5, height: 1.45, color: p.muted)),
        ],
      ),
    );
  }
}
