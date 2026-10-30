# CentsGo

**Il pieno più conveniente, vicino a te.**

CentsGo confronta i prezzi dei carburanti in Italia e ti dice dove conviene davvero fare il pieno:
non solo il distributore più economico, ma quello che ti fa risparmiare di più **anche pagando la
deviazione**. Include mappa, ricerca per zona e autostrada, pianificazione del viaggio, colonnine
elettriche, ZTL e un Garage per rifornimenti, consumi e scadenze.

Un solo codice per **iOS, Android, macOS, Windows e Linux**.

---

## Funzioni

| Area | Cosa fa |
| --- | --- |
| **Pieno intelligente** | Calcola il risparmio *netto* su un pieno (prezzo × litri − carburante speso per la deviazione) e ti dice se conviene muoversi |
| **Lista** | Distributori nel raggio scelto, ordinati per **Prezzo / Distanza / Migliori**, self o servito, colore di convenienza e risparmio stimato |
| **Mappa** | Prezzi sui pin, posizione reale, ricerca "in quest'area", livelli ZTL / colonnine / officine / autolavaggi / gommisti |
| **Cerca** | Per distributore (nome, marchio, indirizzo), per zona (comune/provincia) e per autostrada (A1…A90) |
| **Viaggio** | Partenza e arrivo, deviazione massima configurabile, distributori lungo il percorso, viaggi recenti |
| **Garage** | Veicoli (8 carrozzerie × 8 colori), pieno stimato, autonomia, costo/km, rifornimenti, consumo misurato, spese mensili, scadenze di bollo/assicurazione/revisione |
| **Avvisi** | Preferiti monitorati con rilevazione delle variazioni e storico locale dei prezzi |
| **Aspetto** | Tema chiaro, scuro e **nero AMOLED**; palette arancio; font Plus Jakarta Sans, Archivo Black, IBM Plex Mono |
| **Dati sempre aggiornati** | Prezzi ufficiali MIMIT scaricati in automatico: controllo leggero ogni 30 minuti, download completo solo quando il ministero pubblica il nuovo file (una volta al giorno). Funziona anche al primo avvio, senza attendere l'utente |
| **Dataset** | 21.527 impianti, 23.196 colonnine, 225 ZTL, 14.926 servizi, comuni e province — incluso nell'app per l'uso offline |

Nessuna registrazione, nessun account, nessuna chiave API. L'app funziona offline (tranne le tile
della mappa) e tutti i dati personali restano sul dispositivo.

## Tecnologia

- **Flutter 3.47 / Dart 3.13** — UI e logica condivise su cinque piattaforme.
- **flutter_map** + **latlong2** per la mappa (OpenStreetMap), **geolocator** per la posizione,
  **shared_preferences** per lo stato locale, **url_launcher** per aprire il navigatore,
  **intl** per i formati italiani.
- Architettura semplice e testabile: `AppState` (ChangeNotifier) come unica fonte di verità,
  repository di sola lettura per il catalogo, widget senza stato dove possibile.
- Nessun backend obbligatorio: lo snapshot dei prezzi è incluso e aggiornabile.

```
lib/
├── main.dart / app.dart      bootstrap, temi, routing di primo livello
├── core/                     formati (€, km, date), geodesia, apertura link
├── models/                   Station, Vehicle/Refuel, Settings, Trip, layer mappa
├── data/                     catalogo, layer lazy, storage, listini auto
├── state/                    AppState + LocationService
├── theme/                    palette e tipografia
├── widgets/                  UI kit (card, chip, grafici, disegno veicoli)
└── features/
    ├── list/ map/ search/ trip/ garage/
    ├── station/ alerts/ settings/ common/
assets/
├── data/                     snapshot JSON (impianti, EV, ZTL, POI, comuni)
├── fonts/                    Jakarta, Archivo Black, IBM Plex Mono (SIL OFL)
└── branding/                 icona app (generata da tool/generate_icons.dart)
tool/                         script di build dati, icone, avvio macOS
docs/                         guida di compilazione e roadmap
```

## Avvio rapido

```bash
git clone <url-del-repo> CentsGo && cd CentsGo
flutter pub get

flutter run -d macos      # oppure: ios, android, windows, linux
flutter test              # 22 test
```

Istruzioni dettagliate per ogni piattaforma (Xcode e Android Studio compresi, senza terminale):
**[docs/BUILD.md](docs/BUILD.md)**.

## Dati e aggiornamento

A runtime l'app tiene i prezzi allineati ai dati aperti del **MIMIT — Osservaprezzi carburanti**
senza intervento dell'utente:

1. all'avvio (e al ritorno in primo piano) verifica l'header `Last-Modified` del file ufficiale —
   pochi KB, nessun download se i dati sono già aggiornati;
2. se il file è cambiato scarica anagrafica e prezzi (~8 MB), li unisce e li salva nella cache locale;
3. la lista e la mappa si aggiornano da sole; il controllo successivo avviene dopo 30 minuti.

Il download avviene quindi circa una volta al giorno, quando il ministero pubblica i nuovi prezzi.
In Impostazioni si può disattivare o forzare l'aggiornamento, e si vede l'ora dell'ultima sincronizzazione.

Lo snapshot incluso nel bundle (usato al primo avvio o offline) si rigenera con:

```bash
curl -O https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv
curl -O https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv
python3 tool/build_seed_data.py anagrafica_impianti_attivi.csv prezzo_alle_8.csv
```

Lo script unifica le oltre 60 denominazioni di carburante in 5 famiglie (Benzina, Gasolio, GPL,
Metano, HVO), calcola self e servito, scarta coordinate e prezzi non plausibili e produce un JSON
compatto caricato in un isolate all'avvio.

## Stato di build

| Piattaforma | Stato |
| --- | --- |
| **macOS** | compilato e testato (debug + avvio) |
| **iOS** | compilato (debug e release) e testato su simulatore; su device serve la firma |
| **Android** | APK di release generato, **non ancora testato** su dispositivo/emulatore |
| **Windows** | **non ancora compilato** né testato |
| **Linux** | **non ancora compilato** né testato |

Verifiche automatiche attuali: `flutter analyze` senza errori e `flutter test` con 24 test verdi.

## Contribuire

1. fork + branch (`feat/nome-funzione`);
2. `flutter pub get`, poi `flutter analyze` e `flutter test`;
3. mantieni lo stile esistente (widget piccoli, nessuna dipendenza non necessaria);
4. apri una pull request con una descrizione di cosa cambia e come l'hai provato.

Le idee già pianificate sono in [docs/ROADMAP.md](docs/ROADMAP.md). Per cambiare l'icona:
`flutter test tool/generate_icons.dart && dart run flutter_launcher_icons`.

## Attribuzioni e licenza

- Prezzi e anagrafica impianti: **MIMIT — Osservaprezzi carburanti**, open data (IODL 2.0).
- ZTL, officine, autolavaggi, gommisti, colonnine: **© OpenStreetMap contributors** (ODbL).
- Tile mappa: `tile.openstreetmap.org` per sviluppo/demo; per la distribuzione serve un tile provider
  conforme alla [Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles) o un server proprio.
- Font: **Plus Jakarta Sans**, **Archivo Black**, **IBM Plex Mono** (SIL Open Font License).

Codice distribuito con licenza **MIT** — vedi [LICENSE](LICENSE).
