# Konzola — SSH klijent za Android (zamena za JuiceSSH)

Naziv aplikacije je trenutno „LemonSSH“; menja se u `lib/app_state.dart` (`appName`, a boja trake je `kBrand`) i u
`android/app/src/main/AndroidManifest.xml` (`android:label`).

## Šta ima prva verzija

- **Glavni meni** kao u JuiceSSH-u: Quick Connect, Frequently Used (broji konekcije), Manage Connections, Port Forwards, Settings
- **Konekcije**: SSH, Telnet i lokalni shell na telefonu; nadimak, host, port, korisnik
- **Brzo povezivanje** (⚡): ukucaš `korisnik@host:port` i odmah se povežeš
- **Više sesija odjednom**: sesija ostaje otvorena kad izađeš iz terminala (lista „Active sessions“)
- **Terminal u boji** (xterm-256color), kopiranje/lepljenje, veći/manji font
- **Dodatna tastatura u dva reda** kao u JuiceSSH-u: ESC / | - HOME ↑ END PGUP FN i TAB CTRL ALT ← ↓ → PGDN ⌨
  (FN pa 1–0, -, = daje F1–F12; strelice se ponavljaju dok ih držiš; ⌨ skriva/prikazuje tastaturu)
- **Rad u pozadini**: sesije ostaju povezane kad izađeš iz aplikacije (foreground servis sa notifikacijom); dugme Nazad u glavnom meniju samo minimizuje aplikaciju dok postoji aktivna sesija
- **Rezervna kopija**: Settings → Backup, izvoz u clipboard (sa ili bez lozinki i ključeva) i uvoz
- **Pinch zoom**: povlačenje dva prsta menja veličinu slova u terminalu
- **Teme terminala**: Solarized Dark, Dark, Monokai, Light; veličina slova u podešavanjima
- **SSH ključevi**: generisanje Ed25519 ključa, uvoz postojećeg (OpenSSH/PEM — RSA, ECDSA, Ed25519, i sa lozinkom)
- **Provera ključa servera** (known hosts) sa upozorenjem ako se ključ promeni
- **Snipeti**: sačuvane komande, pokretanje iz terminala ili automatski posle povezivanja
- **Port forwarding**: lokalni (-L) i udaljeni (-R), uključivanje/isključivanje prekidačem
- Lozinke i privatni ključevi čuvaju se u šifrovanom Android skladištu

## Najlakši način: APK preko GitHub-a (bez instaliranja ičega)

1. Napravi novi (privatni) repozitorijum na GitHub-u i ubaci sve fajlove iz ovog foldera
   (uključujući skriveni folder `.github`).
2. Otvori karticu **Actions** — build kreće sam (traje oko 5–10 min).
3. Kad se završi, otvori taj build i dole pod **Artifacts** preuzmi `lemonssh-apk`.
4. Raspakuj zip, prebaci `app-release.apk` na telefon i instaliraj
   (dozvoli „instaliranje iz nepoznatih izvora“).

Ako build padne, pošalji mi tekst greške iz Actions loga i ispraviću kod.

## Lokalno na računaru

Treba ti Flutter (stable) i Android Studio (zbog Android SDK-a).

```bash
cd sshclient
flutter create --platforms=android --org rs.stupovi --project-name lemonssh .
flutter pub get
flutter run            # telefon povezan USB-om, uključen USB debugging
flutter build apk      # gotov APK: build/app/outputs/flutter-apk/app-release.apk
```

`flutter create .` samo dodaje Android fajlove koji fale i ne dira postojeći kod.

## Struktura koda

| Fajl | Šta radi |
|---|---|
| `lib/models.dart` | Konekcija, ključ, snipet, port forward |
| `lib/store.dart` | Čuvanje podataka (JSON + šifrovano skladište) |
| `lib/backends.dart` | SSH, Telnet i lokalni shell |
| `lib/sessions.dart` | Otvorene sesije, CTRL/ALT logika |
| `lib/forwarding.dart` | Port forwarding |
| `lib/keygen.dart` | Generisanje i uvoz SSH ključeva |
| `lib/screens/` | Ekrani aplikacije |

## Šta još nema (za sledeće verzije)

- Rad u pozadini (Android foreground servis) — sada Android može da prekine
  vezu ako aplikacija dugo stoji u pozadini
- Dinamički (SOCKS) port forwarding, Mosh
- Generisanje RSA ključeva (uvoz RSA radi)
- Grupe konekcija, rezervna kopija/sinhronizacija, zaključavanje aplikacije, widget
- Prevod interfejsa na srpski
