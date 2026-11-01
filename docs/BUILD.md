# Compilare CentsGo

Guida unica per tutte le piattaforme. Due modi: **interfaccia grafica** (Xcode / Android Studio /
VS Code) o **terminale**. Il codice è lo stesso ovunque.

| Destinazione | Si compila da | Strumento |
| --- | --- | --- |
| macOS, iOS | macOS | **Xcode** |
| Android | macOS, Windows, Linux | **Android Studio** (o VS Code) |
| Windows | Windows | **VS Code** + Visual Studio 2022 (toolchain C++) |
| Linux | Linux | **VS Code** + pacchetti di sistema |

---

## 0. Preparazione (una volta per PC)

1. **Flutter SDK stabile 3.47+** → https://docs.flutter.dev/get-started/install
   - macOS: scompatta in `~/tools/flutter`, aggiungi `~/tools/flutter/bin` al `PATH`
   - Windows: `C:\src\flutter`, aggiungi `C:\src\flutter\bin` al `PATH`
   - Linux: `~/flutter`, aggiungi `~/flutter/bin` al `PATH`
2. **Git**.
3. **VS Code** con estensione **Flutter** (installa anche Dart) — oppure Android Studio con il plugin Flutter.
4. Clona e apri:

```bash
git clone <url-del-repo> CentsGo
cd CentsGo
```

All'apertura in VS Code/Android Studio l'estensione esegue **Pub get** da sola; altrimenti
`Ctrl/Cmd+Shift+P` → **Flutter: Get Packages** (nessun terminale).

Verifica: `Ctrl/Cmd+Shift+P` → **Flutter: Run Flutter Doctor**.

---

## 1. macOS con Xcode

1. Apri `macos/Runner.xcworkspace` (doppio clic dal Finder).
2. In alto: scheme **Runner**, destinazione **My Mac**.
3. **⌘R** (compila e avvia) oppure **⌘B** (solo compilare).
4. Il bundle è in **Product → Show Build Folder in Finder** → `Build/Products/Debug/CentsGo.app`.

Nessun team di firma serve per l'uso locale. Per distribuire: **Product → Archive**.

> La finestra parte a 720×900 ed è ridimensionabile: sopra i 700 px la lista diventa a due colonne.

## 2. iOS con Xcode

### 2.1 Prerequisito (una volta sola, richiede password admin)

**Xcode → Settings… (⌘,) → Locations → Command Line Tools = Xcode 27.x**
(oppure `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`).

Serve perché una dipendenza della mappa compila *native assets* con un hook che invoca `xcrun` in un
ambiente ripulito, **ignorando `DEVELOPER_DIR`**: con i Command Line Tools attivi `xcrun` non trova
la SDK iOS e la build fallisce con:

```
Bad state: No element
  firstLineOfStdout (objective_c-*/hook/build.dart)
Target build_hooks failed: Error: Building native assets failed.
Command PhaseScriptExecution failed with a nonzero exit code
```

Verifica rapida: `xcrun --show-sdk-path --sdk iphoneos` deve stampare un percorso.

### 2.2 Simulatore (nessuna firma)

1. `open -a Simulator`
2. Apri `ios/Runner.xcworkspace`
3. Scheme **Runner**, destinazione *iPhone 16 Pro* (o altro simulatore)
4. **⌘R**

### 2.3 iPhone fisico

1. iPhone collegato e sbloccato, rispondi **Fidati**; su iOS 16+ attiva
   **Impostazioni → Privacy e sicurezza → Modalità sviluppatore** e riavvia.
2. Xcode → **Settings → Accounts** → `+` → il tuo Apple ID.
3. Target **Runner → Signing & Capabilities**:
   - **Team**: il tuo;
   - **Bundle Identifier**: univoco, es. `com.tuonome.centsgo` (anche su `RunnerTests`);
   - **Automatically manage signing** attivo.
4. Destinazione = il tuo iPhone → **⌘R**.
5. Primo avvio: **Impostazioni → Generali → VPN e gestione dispositivi → Autorizza**.

Con Apple ID gratuito la firma dura 7 giorni (ricompili). Deployment target: iOS 15.0.

---

## 3. Android con Android Studio

Serve Android Studio con SDK e almeno un emulatore (una volta):

1. installa Android Studio e lascia che installi **Android SDK**, **SDK Platform 35+**,
   **Platform-Tools**, un emulatore (**Device Manager → Create Device**);
2. **Settings → Plugins → Flutter** (porta con sé Dart), riavvia;
3. **File → Open…** → la **cartella radice `CentsGo`** (non `CentsGo/android`);
4. scegli emulatore o telefono (debug USB attivo) → **Run ▶**.

APK: **Build → Build Bundle(s)/APK(s) → Build APK(s)** →
`android/app/build/outputs/apk/debug/app-debug.apk`.

L'APK di release si crea con una keystore (`android/key.properties`).

---

## 4. Windows

Su una macchina Windows, una volta sola:

- **Visual Studio 2022** con workload **“Sviluppo di applicazioni desktop con C++”**
  (include Windows 10/11 SDK e CMake): serve solo come toolchain;
- **Flutter SDK** + **VS Code con estensione Flutter**.

Poi, con la cartella `CentsGo` aperta in VS Code:

1. **Flutter: Get Packages**;
2. in basso a destra seleziona il device **Windows (desktop)** (se manca:
   *Flutter: Select Device*);
3. **F5**.

Release: `flutter build windows --release` → `build\windows\x64\runner\Release\CentsGo.exe`
(distribuisci **tutta** la cartella: exe + DLL + `data/`).

> Aprire `windows/Runner.sln` in Visual Studio non basta: la parte Dart la compila solo il tool Flutter.

## 5. Linux

Su Linux (Ubuntu/Debian), una volta sola:

```bash
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libgeoclue-2-dev
```

Poi Flutter SDK + VS Code con estensione Flutter: apri `CentsGo`, **Flutter: Get Packages**,
device **Linux (desktop)**, **F5**.

Release: `flutter build linux --release` → `build/linux/x64/release/bundle/` (cartella intera).

---

## 6. Riga di comando (equivalente)

```bash
flutter pub get
flutter run -d macos            # oppure: ios, <udid>, android, windows, linux
flutter build macos --release
flutter build ios --release     # senza firma: --no-codesign
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
flutter build linux --release
```

Flag di debug utili (solo per QA):

```bash
flutter run --dart-define=START_TAB=1 --dart-define=SKIP_ONBOARDING=true
# 0 Lista · 1 Mappa · 2 Cerca · 3 Viaggio · 4 Garage
```

## 7. CI senza PC

`.github/workflows/build.yml` compila a ogni push macOS, iOS (senza firma), Android, Windows e Linux,
e carica gli artefatti nella pagina **Actions** del repository.

---

## 8. Test

```bash
flutter analyze     # 0 errori
flutter test        # 44 test
```

Copertura attuale: parsing dello snapshot MIMIT, plausibilità dei prezzi, ordinamenti
(prezzo/distanza/migliori), pieno intelligente, unità di misura per carburante (L/kg/kWh),
conversione L/100 ⇄ km/L, diario rifornimenti con pieni parziali, indice indirizzi offline,
decoder polilinea, motore pedaggi (tratte, classi, minimo, arrotondamento), motore costi di viaggio
(carburante, pedaggio, split), e uno smoke test che renderizza le cinque schermate a 393×852 pt con
i font reali (gli overflow di layout fanno fallire il test).

---

## 9. Problemi frequenti

| Messaggio | Rimedio |
| --- | --- |
| `Building native assets failed` / `SDK "iphonesimulator" cannot be located` | §2.1: Command Line Tools → Xcode |
| `Signing for "Runner" requires a development team` | Signing & Capabilities → scegli il Team |
| `Failed to register bundle identifier` | cambia Bundle Identifier |
| `Flutter-Generated.xcconfig` mancante dopo un clean | **Flutter: Get Packages** |
| VS Code non vede il device Windows | manca il workload C++ di Visual Studio 2022 |
| `CMake not found` (Linux) | `sudo apt install cmake ninja-build clang pkg-config libgtk-3-dev` |
| Android: `SDK location not found` | apri Android Studio e installa l'SDK, o `flutter config --android-sdk <path>` |
| Mappa grigia/vuota | serve rete per le tile OpenStreetMap; il resto funziona offline |
| Posizione non disponibile | l'app resta usabile: scegli la zona dal campo in alto (resta memorizzata) |
| Warning `authorizationStatus is deprecated` | warning del plugin geolocator, ignorabile |
