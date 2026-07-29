# GymLog — Frontend (Flutter)

```
frontend/
├── lib/
│   ├── main.dart                        entrypoint + Supabase.initialize
│   ├── app.dart                         providers, theme, AuthGate
│   ├── core/
│   │   ├── env.dart                     --dart-define config
│   │   ├── theme.dart                   Material 3 theme + Panel widget
│   │   └── formatting.dart              dates, weights, pluralisation
│   ├── models/                          Exercise, Workout, WorkoutSet
│   ├── services/                        AuthService, ExerciseService, WorkoutService
│   ├── screens/
│   │   ├── auth/login_screen.dart       email + password, Google, reset
│   │   ├── main_shell.dart              bottom nav: Today | History
│   │   ├── home/home_screen.dart        today's session
│   │   ├── home/add_exercise_screen.dart pick exercise, enter sets
│   │   └── history/…                    past days + detail
│   └── widgets/
│       ├── exercise_picker.dart         the searchable dropdown
│       ├── exercise_group_card.dart
│       └── google_button.dart
└── tool/bootstrap.ps1                   generates android/ ios/ web/
```

State is plain `ChangeNotifier` + `provider`. Three notifiers, no routing package,
no code generation — the app is small enough that anything heavier would be
overhead.

## First-time setup

**1. Generate the platform folders.** This repo holds only the Dart source, so
`android/`, `ios/` and `web/` need to be created once:

```bash
pwsh -File tool/bootstrap.ps1
```

(Don't run `flutter create .` here directly — it overwrites `pubspec.yaml` and
`lib/main.dart` with its own templates. The script scaffolds into a temp folder
and copies only the platform directories across.)

**2. Point the app at your Supabase project.**

```bash
cp env.example.json env.json
```

Fill in the URL and anon key from **Project Settings → API**. `env.json` is
gitignored. Then:

```bash
flutter run --dart-define-from-file=env.json
```

If you skip this the app boots into a screen telling you exactly what's missing
rather than crashing.

## Google sign-in

Sign-in goes through `signInWithOAuth`, which opens the system browser and comes
back into the app through a deep link. One code path for Android, iOS and web —
no native Google SDK, no client IDs baked into the app.

The database side (enabling the provider, the redirect URL allowlist) is covered
in `backend/README.md`. On this side, register the URL scheme:

**`android/app/src/main/AndroidManifest.xml`** — inside the existing
`<activity android:name=".MainActivity">`, alongside the launcher intent-filter:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.supabase.gymlog" android:host="login-callback" />
</intent-filter>
```

**`ios/Runner/Info.plist`** — inside the top-level `<dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>io.supabase.gymlog</string>
    </array>
  </dict>
</array>
```

The scheme appears in exactly three places — those two files and
`Env.authRedirectUrl` in `lib/core/env.dart` — plus the Supabase dashboard.
Change one, change all four.

For **web**, no deep link is needed: `redirectTo` is left null and Supabase
returns to the page the user started from. Add that origin (e.g.
`http://localhost:3000`) to the dashboard's redirect allowlist, and run with
a fixed port:

```bash
flutter run -d chrome --web-port 3000 --dart-define-from-file=env.json
```

## How the exercise dropdown works

`showExercisePicker()` opens a full-screen search page rather than a dropdown
menu — the catalogue is ~75 entries out of the box and grows, which is more than
a menu handles well, and the search field needs the keyboard up the whole time.

The catalogue is fetched once into `ExerciseService` and filtered in memory, so
typing is instant. Prefix matches rank above substring matches, so "bench"
surfaces *Bench Press* before *Close Grip Bench Press*.

When what you type doesn't match anything, an **Add "…"** tile appears at the
top. Tapping it calls the `add_exercise` RPC, which saves it against your account
and returns it — from then on it's in the dropdown under **Your exercises**, and
only you see it. If the name already exists the RPC hands back the existing row
instead of creating a near-duplicate.

## Notes on behaviour

- **One workout per calendar day.** Adding an exercise attaches it to that day's
  workout, creating it on first use. Logging the same exercise twice in a day
  continues the set numbering rather than starting over.
- **Backfilling.** The add screen has a date field, capped at today, so you can
  log a session you forgot about. From a history entry, the FAB adds to *that*
  day.
- **Weight is optional** — leave it blank for bodyweight work and the set shows
  as "12 reps" instead of "12 × 40 kg".
- **Sessions persist** across app restarts; `supabase_flutter` stores and
  refreshes the token itself.

## Building for release

```bash
flutter build apk --release --dart-define-from-file=env.json
```

```bash
flutter build web --release --dart-define-from-file=env.json
```

`--dart-define` values are compiled into the binary. The anon key belongs there;
the `service_role` key never does.
