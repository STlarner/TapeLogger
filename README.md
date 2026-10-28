# TapeLogger

Logging per iOS che si vede: una console testuale colorata e una UI SwiftUI
navigabile, dallo stesso modello dati.

```swift
Tape.info("app launched")
Tape.warning("cache miss", metadata: ["key": "feed", "retry": 3])
Tape.error(error)
```

```
🟠 ┌ http-request | 21:30:34.584 | 584ms
   │ GET https://jsonplaceholder.typicode.com/users/1
   └──────────────────────────────────────────────
```

## Perché

La console di Xcode non supporta i codici ANSI: colorare il testo con escape
codes lì non funziona (e può troncare la riga). Quindi la palette è semantica
e ogni destinazione la degrada come può:

| Destinazione | Come appare |
| --- | --- |
| Terminale / CI | colore ANSI 256 |
| Console Xcode | badge emoji |
| UI in-app | colore pieno light/dark |

## Installazione

```swift
.package(url: "https://github.com/<owner>/TapeLogger.git", from: "0.1.0")
```

Product: `TapeLogger` (core, zero dipendenze) e `TapeLoggerUI` (SwiftUI).

## Uso

```swift
import TapeLogger

// Livelli allineati a os.Logger: trace, debug, info, notice, warning, error, critical, fault
Tape.debug("cache hit", metadata: ["key": "feed"])
Tape.notice("session refreshed")

// Chiavi: l'id è stabile (filtri, tema), il titolo è quello che si legge
let payments = TapeKey("payments", title: "payments", level: .notice)
Tape.log("charged", key: payments, metadata: ["amount": 19.99, "currency": "EUR"])

// Durata misurata
let users = try await Tape.measure("load users") { try await api.users() }
```

Sink aggiuntivi (console incluso di default):

```swift
Tape.shared.addSink(
    TapeOSLogSink(subsystem: "com.example.app", category: "app")
)
```

Inoltro al log unificato, così le entry restano visibili in Console.app e
Instruments. Il verso opposto (catturare `os_log` di terzi) non è possibile
su iOS: nessun framework pubblico espone il log unificato in lettura.

## UI

```swift
import TapeLoggerUI

WindowGroup {
    ContentView()
        #if DEBUG
        .tapeConsole(trigger: .shake)
        #endif
}
```

`trigger` sceglie come si apre:

- `.button` (default): bottone flottante in basso a destra.
- `.shake`: shake del device, nessun elemento visibile. Funziona solo su
  dispositivo fisico, il Simulator non ha il gesture.
- `.none`: nessun trigger, presenti `TapeConsoleView()` tu.

C'è ricerca, filtro per livello e tap sulla card per espandere metadata,
sorgente e allegati.

## Architettura

```
Tape.log ──► TapeEntry ──┬─► TapeStore ──► AsyncStream ──► TapeConsoleView
                         └─► TapeSink[] ──► TapeConsoleSink ──► TapeTextRenderer
                                          └─► TapeOSLogSink
```

- **`TapeEntry`**: solo contenuto (livello, chiave, messaggio, metadata,
  durata, allegato, sorgente). Non sa come verrà mostrato.
- **`TapeSink`**: destinazione. `record` è sincrono e non blocca; viene
  chiamato fuori dai lock, quindi può rientrare in `Tape` (protetto da un
  guard thread-local contro la ricorsione).
- **`TapeTextRenderer`**: trasforma un entry in testo.
- **`TapeTheme`**: `levels` + override per `keys`; nessun colore hardcoded
  nei renderer.

Hot path: un unfair lock per entry, nessun actor e nessun task per log.
Storia limitata (default 1000) e stream `.bufferingNewest(2000)`.

## Test

```bash
swift test
```

`Package.swift` dichiara `.macOS(.v14)` solo per poter eseguire i test in
locale: il target supportato è iOS 17+.

## Roadmap

- [ ] Filtro per chiave nella UI
- [ ] Pausa / auto-scroll
- [ ] Export (testo, JSON)
- [ ] Adapter di rete (`Tape.session`), `TapeAdapter` per installazioni globali
- [ ] Persistenza su file

## Licenza

MIT — vedi [LICENSE](LICENSE).
