# Skipper

A student attendance tracker for Indian colleges. It tells you exactly how many classes you can skip and still stay at or above 75% (or whatever target you set), and how many you need to attend to recover.

Built with Flutter: Provider for state, Hive for local storage, and Google's public holiday calendar (a REST endpoint, no key needed) for India's holidays.

## Run

```sh
flutter pub get
flutter run
```

Developer flags:

| Flag | What it does |
|---|---|
| `--dart-define=DEMO=true` | Loads a sample semester on launch |
| `--dart-define=SCREEN=attendance` | Opens a screen on launch: `attendance`, `planner`, `detail`, `overall`, `settings`, `timetable`, `holidays`, `breaks`, `pending`, `form` |

## Test

```sh
flutter test
```

The tests include an exhaustive check of the skip/recover maths against brute force (376,431 cases), the schedule engine, the long-weekend finder, the leave planner, API parsing, and form validation.

## Requirements covered

- **Multiple screens + navigation**: onboarding, Today, Attendance, subject/overall detail, Planner, Pending, Timetable, Subject form, Holidays & breaks, Settings. Uses named routes plus container-transform transitions.
- **Provider**: Settings, Timetable, Holiday, Attendance (`ChangeNotifierProxyProvider3`) and Planner providers.
- **REST API**: `GET` on Google's public India holiday feed (iCalendar), parsed by hand, cached in Hive, with a loading shimmer, offline/server error states and retry. Tests use a mocked HTTP client.
- **Forms with validation**: subjects, starting numbers, breaks, holidays.
- **Animation + theming**: swipe-to-mark with spring physics, rolling numbers, animated rings, confetti, Material 3 light and dark themes with selectable accents.

Fonts: Geist and Bricolage Grotesque (SIL Open Font License, see `assets/fonts`).
