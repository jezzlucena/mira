# Mira

> **The Mirror, Not the Judge.**

Mira is a harm-reduction focused habit tracker for iOS and Apple Watch. Unlike traditional trackers that gamify perfection with streaks and chains, Mira treats every log — even a "bad" day — as a valuable data point. It pairs every habit entry with a mandatory sentiment score (1–6), then uses correlation analysis to reveal the relationship between what you do and how you feel.

Track anything without judgment: meditation, water intake, smoking, nail-biting, sleep. Mira doesn't label habits as "good" or "bad" — you decide what matters.

## Philosophy

Most habit apps punish you for missing a day. Mira doesn't. There are no streaks, no shame, no gamification. The core idea is **self-observation over self-optimization**: understand your patterns, then decide what to do about them.

Every entry requires a sentiment rating on a 1–6 scale (deliberately even — no neutral middle ground, which forces honest reflection). Over time, the analytics engine correlates your habits with your mood, surfacing insights like *"You tend to smoke when your mood is a 2, and feel a 5 right after — but a 1 two hours later."*

See [MISSION_VISION.md](MISSION_VISION.md) for the full product philosophy.

## Features

### iOS App

- **Dashboard** — Today's mood summary, 7-day sentiment trend chart, quick-log shortcuts, and recent activity
- **Habit Management** — Create habits with custom icons (SF Symbols), colors, and tracking styles (occurrence, duration, or quantity). Reorder, archive, and tag habits freely
- **Quick Logging** — 3-step flow: pick habit → rate sentiment → add optional details. Designed for under 5 seconds
- **Analytics** — Pearson correlation between habits and mood, day-of-week patterns, mood trends over 7/30/90 days, and natural-language insights
- **HealthKit Integration** — Read-only access to sleep, steps, heart rate, and HRV. Correlates health metrics with mood
- **Data Export/Import** — Full JSON backup with merge or replace import modes. You own your data
- **Settings** — Accessibility options (haptics, motion, high contrast, dyslexia font), biometric lock, app-switcher hiding, iCloud sync toggle

### watchOS App

- **Quick Logging** — Digital Crown for sentiment and value input. Optimized for 2–3 taps
- **Entry Management** — View, edit, and delete today's entries from your wrist
- **CloudKit Sync** — Automatically syncs with the iOS app via iCloud

### Privacy

- **Local-first by default** — Data stays on-device unless you explicitly enable iCloud sync
- **Local-only habits** — Mark sensitive habits to prevent them from syncing to the cloud
- **No analytics, no ads** — Zero telemetry. No third-party SDKs

## Architecture

```
MiraKit/          ← Shared business logic (iOS + watchOS)
├── Models/       ← SwiftData models (Habit, HabitEntry, SentimentRecord, UserPreferences)
├── Repositories/ ← Data access layer (HabitRepository, EntryRepository, etc.)
├── Services/     ← Business logic (HabitService, AnalyticsEngine, HealthKitManager, ExportService)
├── DI/           ← DependencyContainer with environment-based injection
└── Extensions/   ← Shared utilities (Color+Hex, sentiment helpers)

MiraApp/          ← iOS app target
├── App/          ← Entry point, root navigation
├── Features/     ← Feature modules (Dashboard, Habits, Logging, Analytics, Settings, Onboarding)
├── Components/   ← Reusable UI (SentimentPicker, TrendChart, HabitCard, GlassButton)
└── Resources/    ← Asset catalogs

MiraWatch/        ← watchOS app target
├── App/          ← Entry point
├── Features/     ← HabitList, Logging, Entries
└── Components/   ← Watch-specific UI (WatchSentimentPicker, WatchValueInput)

MiraTests/        ← Unit tests (Swift Testing)
```

**Pattern:** Repository → Service → DI Container → SwiftUI Views

The app uses SwiftData for persistence with optional CloudKit sync. Dependency injection flows through the SwiftUI environment via `@Environment(\.dependencies)` and the `.withDependencies()` modifier. iOS-only services (AnalyticsEngine, HealthKitManager, ExportService) are conditionally compiled with `#if !os(watchOS)`.

## Models

| Model | Purpose |
|---|---|
| `Habit` | A tracked behavior with name, icon, color, tracking style, tags, and display order |
| `HabitEntry` | A single log tied to a habit — includes mandatory sentiment (1–6), optional value/note |
| `SentimentRecord` | A standalone mood log, not tied to any habit |
| `UserPreferences` | App settings: accessibility, privacy, notifications, display, sync |

### Sentiment Scale

| Value | Emoji | Label |
|---|---|---|
| 1 | 😞 | Awful |
| 2 | 😔 | Rough |
| 3 | 😕 | Meh |
| 4 | 🙂 | Okay |
| 5 | 😊 | Good |
| 6 | 😄 | Great |

## Requirements

- **iOS 17.0+**
- **watchOS 11.0+**
- **Xcode 16+**
- **Zero external dependencies** — built entirely on Apple frameworks (SwiftUI, SwiftData, Charts, HealthKit, Combine)

## Getting Started

1. Clone the repository:
   ```bash
   git clone git@github.com:jezzlucena/mira.git
   cd mira
   ```

2. Open in Xcode:
   ```bash
   open Mira.xcodeproj
   ```

3. Select the **Mira** scheme for iOS or **MiraWatch Watch App** for watchOS.

4. Build and run (Cmd+R).

No package resolution needed — there are no external dependencies.

## Testing

The test suite uses Swift Testing (`@Test` macro). Run tests with:

```bash
xcodebuild test -project Mira.xcodeproj -scheme Mira -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or use Cmd+U in Xcode.

Tests cover model validation, sentiment clamping, analytics correlation calculations, and export/import round-trips. A `DependencyContainer.forTesting()` factory provides an in-memory SwiftData container for isolated tests.

## License

[MIT](LICENSE) — Copyright (c) 2026 Jezz Lucena
