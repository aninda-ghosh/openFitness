# Changelog

All notable changes to openFitness are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Versions follow [Semantic Versioning](https://semver.org/).

---

## [0.4.0] — 2026-07-10

### Added
- **Stale Sleep Data Banner**: Added a visual warning banner at the top of `SleepDetailView` when no sleep data is recorded today, alerting the user that fallback/stale data from a previous day is shown.
- **Solid Segmented Score Zones**: Replaced the continuous gradient bar under Dashboard's Score Zones with four clean, solid-color segment capsules.
- **Interactive Swipe Back Gesture**: Restored native iOS interactive swipe-to-go-back gesture globally across hidden-navigation detail pages.

### Changed
- **Minimalist Pure Black & Solid Color Theme**: Removed all gradients, meshes, backglows, and radial shadows. Replaced app backgrounds with flat `Color.black` and progress/gauge rings and charts with solid colors and flat fills.
- **Strict Vertical Scroll Lock**: Bound the inner VStack content of all 10 detail views and the main Dashboard to `.containerRelativeFrame(.horizontal)` to guarantee purely vertical scrolling and prevent any horizontal shifting.
- **Dashboard Header Spacing**: Increased top spacing of the Dashboard header to 54pt to completely prevent status bar collisions on notched devices.
- **Uniform Alignments**: Adjusted the horizontal padding on the Dashboard's "Daily summary" section from 20pt to 16pt to align perfectly with the other cards.
- **AI Nudge Pipeline Refactoring**: Configured the dashboard nudge (`DailyPulse`) to run *after* metric sub-insights are generated, summarizing those sub-insights rather than using raw values.
- **Detailed AI Metric Cards**: Moved `MetricInsightCard` from the top of the metric pages to the bottom of all 8 detail views.
- **Robust Background Data and AI Sync**: Shifted `BGAppRefreshTask` and HealthKit updates to trigger a complete HealthKit data fetch via `fetchAllMetrics()` to sync data and pre-warm AI insights in the background.
- **Stale Sleep AI Guard**: Configured the facts model to supply empty sleep context when `isSleepDataStale` is true, aligning the AI summary with the dashboard's `N/A` state.
- **Energy Bank Layout Improvements**: Refactored the statistics pill row to be flexible and restricted options of the segmented picker to [.day, .week, .month, .sixMonths, .year] to match the other pages.
- **Dashboard Daily Summary Section Text**: Removed the daily summary header title and summary text entirely, displaying the circular gauges directly below the Hero Card.

### Removed
- **ECG & Sensor Waveforms**: Removed the ECG card, detail sheets, alerts, and state management variables from the Dashboard.
- **Dashboard AI Nudge bubble**: Removed the dashboard DailyPulseCard as requested.

---

## [0.3.0] — 2026-06-09

### Added
- **Body Composition section** on the Dashboard — 2×2 grid of tiles for Body Fat %, VO₂ Max, BMI, and Body Weight, each linking to a dedicated detail view.
- **`VitalsDetailView` for body composition** — extended lookback windows (60 days for 3-day view, 90 days for week, 6 months for month, 3 years for year) to surface infrequently measured data; starts at 3-day (no day view).
- **`ActivenessDetailView`** — full history and trends for the Activeness Score with day / 3-day / week / 30-day / year timeframe selectors, period-averaged sub-score breakdown, and a settings entry point.
- **User-configurable activity thresholds** — `ActivityThresholdSettingsSheet` lets users set daily steps goal (3k–20k), calorie goal (200–1 200 kcal), and optimal strain (5–20). Changes trigger a 7-day recalibration window shown as a badge on the Activeness Score card.
- **WidgetKit extension** (`openFitness-widgetExtension`) — medium home-screen widget displaying Activeness Score, Recovery, Sleep, Strain, active steps, and calories. Reads shared data via iCloud Key-Value Store.
- **Background sync** — `HKObserverQuery` with `enableBackgroundDelivery` for HRV, RHR, steps, and active energy wakes the app on new data; `BGAppRefreshTask` (`openFitness.bg.refresh`) fires every ~15 min as a fallback. Both paths update the widget via `WidgetCenter.reloadAllTimelines()`.
- **`SharedStore`** — iCloud KV Store wrapper that the main app writes to after every metrics load and the widget reads from.

### Changed
- Replaced **Lean Body Mass** tile with **Body Weight** (`HKQuantityTypeIdentifierBodyMass`) throughout Dashboard, HealthKitManager, and HealthKitIngester.
- **Activeness Score card** redesigned: score and arc gauge on separate lines to prevent title wrapping; calibration badge shows "RECALIBRATING Xd" (orange) or "CALIBRATED" (green).
- **Month-view X-axis labels** now show actual dates ("1 Jun", "8 Jun" …) instead of day-of-week names ("Sat", "Sun").
- **X-axis label thinning** applied to all dense chart views — renders at most every nth label (`step = max(1, count / 8)`) to prevent overflow beyond screen bounds.
- **Activeness Score gauge and sub-score breakdown** now reflect the selected timeframe (week / month / year) by averaging historical daily metrics rather than always showing today's values.
- `HealthKitManager` gains a `static let shared` singleton for use by background task handlers.
- `openFitnessApp` adopts `@UIApplicationDelegateAdaptor(AppDelegate.self)` to register background tasks and HealthKit observer queries at launch.

### Fixed
- Body composition vitals detail views showing empty charts for week / month / year timeframes.
- End-date boundary bug where readings recorded on the current day were excluded from "today" queries.
- Month/6-month chart keying colliding across years (Jan 2024 and Jan 2025 were merged into one bar).
- Component breakdown on `ActivenessDetailView` not updating when switching timeframes.

## [0.2.0] — 2026-06-07

### Added
- Dedicated deep-dive `WorkoutAnalysisDetailView` page featuring timeframe selectors (Day, Week, Month, Year), statistics grids, heart rate intensity distribution cards, and a history list.
- Premium weekly `WorkoutPatternCard` on the Dashboard showing total workouts, duration, active calories, average strain, and a horizontal stacked capsule bar representing intensity zone distribution.

### Changed
- Standardized and aligned timeframe X-axis labels across all metric detail view charts (Activity, Sleep, Recovery, Stress/HR, Vitals, Energy Bank, and Workout Analysis):
  - **Day**: 8 segments of 3 hours each (`["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]`).
  - **Week**: 7 days showing 3-letter weekday names instead of single-letter prefixes.
  - **Month**: 4 weeks labeled as "Week 1", "Week 2", "Week 3", and "Week 4" positioned at week boundaries (indices 3, 10, 17, and 24).
  - **Year**: 12 months showing 3-letter month abbreviations instead of single-letter prefixes.
- Reordered the main dashboard cards: moved the `ECGCardView` to the very bottom of the ScrollView.

---

## [0.1.0] — 2026-06-06

First functional release. Establishes the full data layer, score engine, and all primary screens.

### Added

#### Core Data Layer (`HealthKitManager`)
- `HealthKitManager` observable class — orchestrates all HealthKit queries via `DispatchGroup` fan-out and publishes results as `@Published` properties
- Queries for: sleep analysis (stages + duration), HRV (21-day rolling window), resting heart rate (21-day rolling window), active energy + workouts (last 5), ECG samples, respiratory rate, SpO₂, wrist/body temperature, average + maximum heart rate, step count
- 365-day historical data engine for chart views — fetches active calories, RHR, HRV, sleep, workouts, and HR stats per day with no mock fallbacks
- `fetchAllMetricsAsync()` async wrapper for pull-to-refresh support
- `fetchWorkoutDetails(for:)` — per-workout HR samples, zone distribution, HRR at 1 and 2 min post-workout, downsampled waveform
- `fetchECGVoltageSamples(for:)` — raw voltage waveform points from `HKElectrocardiogramQuery`
- Stress engine — intraday HRV sample variance mapped to 0–100 stress range with high/low tracking
- Energy Bank calculation — composite of recovery + sleep scores minus strain depletion

#### Score Algorithms (`PhysiologicalCalculators`)
- `calculateRecovery` — log-HRV Z-score (60%) + inverted RHR Z-score (40%), clamped 0–100; supports live calibration, stored `UserDefaults` baseline fallback, and population defaults
- `calculateStrain` — Edwards eTRIMP mapped via `21 × (1 − e^(−0.0035 × eTRIMP))` to a 0–21 logarithmic scale
- `calculateSleepScore` — four-component weighted score: duration (40 pts), deep sleep (30 pts), REM (20 pts), nocturnal HR dip (10 pts)
- `calculateActivenessScore` — six-component calibrated composite (Recovery 25%, Strain Balance 20%, Sleep 20%, Activity 15%, HRV Trend 10%, Stress inverse 10%); Strain Balance uses a bell-curve centred at strain 11
- `saveCalibration` / `getStoredBaseline` — persist HRV/RHR mean and standard deviation to `UserDefaults`; only updates when new sample count exceeds previous save

#### Dashboard (`DashboardView`)
- Main scrollable dashboard with pull-to-refresh
- LIVE / OFFLINE HealthKit status badge
- Hero card — `ActivenessScoreCard` (calibrated) with arc gauge, classification label, score description, and five sub-score pills; falls back to a "Stay Active" card before calibration
- `ⓘ` info button on the Activeness Score card opens `ActivenessScoreInfoSheet` — score zone gradient bar, proportional weight distribution bar, and compact sub-score table with mini fill bars
- Daily Summary card — three circular ring gauges (Recovery, Strain, Sleep) linking to detail views
- Today's Activity card — steps progress bar (goal 10k) and active energy bar (goal 600 kcal)
- Energy Bank card — gradient fill bar with contextual readiness message
- Stress & Heart Rate card — range slider with average dot, resting / average / max HR
- Vitals Monitor grid — six `VitalTileView` tiles (HRV, RHR, respiratory rate, SpO₂, temperature, sleep duration) each with status badge and indicator slider
- ECG card — launches raw waveform sheet or shows guidance if no recording found
- Recent Workouts list — name, duration, date, strain contribution, calories; links to workout detail

#### Detail Views
- `RecoveryDetailView` — HRV and RHR trend charts, 21-day baseline stats, cardio distribution breakdown
- `StrainDetailView` — strain trend chart, workout contribution list, target range indicator
- `SleepDetailView` — sleep stage hypnogram, stage breakdown cards, duration trend chart
- `StressHeartRateDetailView` — stress timeline, HR trend chart, range statistics
- `WorkoutDetailView` — per-workout HR waveform, recovery curve, HR zone bar chart, HRR stats, distance and pace

#### Shared Components (`SharedComponents`)
- `CustomLineGraph` — smooth bezier line chart with variance envelope, gradient area fill, vertex nodes, and min/max callout labels
- `CircularGaugeView` — arc ring gauge with angular gradient
- `SleepHypnogramChart` — timeline hypnogram with stage lanes
- `CustomSegmentedPicker` — D / W / M / Y timeframe selector
- `ECGDetailSheet` — clinical-grid ECG waveform viewer with horizontal scroll, amplitude gain slider
- `ECGBackgroundGrid` — pink-paper ECG grid with minor (0.04 s) and major (0.2 s) lines
- Helper row views: `VitalTileView`, `SleepStageCard`, `SleepStageLegendRow`, `HRZoneRowView`, `CardioBreakdownRow`

#### Design System (`Theme`)
- `Theme.Colors` — warm charcoal background, dark card background, neon lime green (recovery), teal (sleep/HRV), neon orange (strain/stress)
- `Theme.Typography` — rounded system font helpers (`metricLabel`, `cardTitle`, `bodyText`, `valueLabel`)
- `.glassCard()` view extension — solid dark card with border and shadow
- `TactileButtonStyle` — spring-scale press feedback
- `VisualEffectView` — UIKit blur bridge for sheet backgrounds
- `SheetBackgroundModifier` — `.ultraThinMaterial` on iOS 16.4+, dark fallback below

#### In-app FAQ (`FAQView`)
- Accordion FAQ screen accessible via `?` button in the Dashboard nav bar
- Four sections: Getting Started, Scores, Vitals & ECG, Privacy & Data
- 14 questions with colour-coded icon badges; tap to expand/collapse with spring animation
- Privacy footer confirming on-device processing

#### Project Files
- `.gitignore` — Xcode, SPM, CocoaPods, Carthage, Fastlane, macOS exclusions
- `README.md` — feature table, requirements, getting started, architecture tree, all four score formulas, privacy statement
- `openFitness.entitlements` — `com.apple.developer.healthkit` entitlement

### Changed
- `ContentView` simplified to a single `DashboardView()` root (removed scaffolding)
- App icon updated to OpenFitness brand logo

### Removed
- Scroll indicators removed from all `ScrollView` instances across the app (Dashboard, 4 detail views, ECG sheet, info sheet, FAQ)
