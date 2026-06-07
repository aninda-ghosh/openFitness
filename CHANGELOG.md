# Changelog

All notable changes to openFitness are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Versions follow [Semantic Versioning](https://semver.org/).

---

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
