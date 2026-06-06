# openFitness

An open-source iOS fitness dashboard that reads Apple Health data and synthesises it into three daily physiological scores — **Recovery**, **Strain**, and **Sleep** — plus a composite **Activeness Score** once your personal baseline is calibrated.

> See [CHANGELOG.md](CHANGELOG.md) for a full history of changes.

---

## Features

| Feature | Description |
|---|---|
| **Recovery Score** (0–100%) | HRV and resting heart rate scored as Z-scores against your 21-day personal baseline |
| **Strain Score** (0.0–21.0) | Cardiovascular training load via Edwards TRIMP, mapped logarithmically |
| **Sleep Score** (0–100%) | Duration, deep sleep, REM, and nocturnal HR dip combined |
| **Activeness Score** (0–100%) | Calibrated composite of all six physiological dimensions — unlocks after 21 days |
| **Energy Bank** | Composite reserve derived from recovery + sleep − strain |
| **Stress Monitor** | Intraday HRV-derived stress with range tracking |
| **Vitals Monitor** | HRV, resting HR, respiratory rate, SpO₂, skin temperature, sleep duration |
| **ECG Viewer** | Raw Apple Watch ECG voltage rendered on a clinical grid with adjustable gain |
| **Workout History** | HR zone breakdown, HRR at 1 and 2 min post-workout, pace and distance |
| **365-day Charts** | Historical trends for every metric with D / W / M / Y timeframe views |
| **In-app FAQ** | Accordion help screen covering scores, vitals, privacy, and calibration |

---

## Requirements

| | Minimum |
|---|---|
| iOS | 16.0 |
| Xcode | 15.0 |
| Device | iPhone (HealthKit unavailable on Simulator) |
| Apple Watch | Recommended — required for HRV, RHR, ECG, sleep stages, and wrist temperature |

---

## Getting Started

```bash
git clone https://github.com/<your-handle>/openFitness.git
open openFitness.xcodeproj
```

1. Select your physical iPhone in Xcode and press **⌘R**.
2. Grant HealthKit read permissions on first launch.
3. Recovery, Strain, and Sleep scores populate immediately from existing Health data.
4. The **Activeness Score** hero card unlocks automatically once 21+ days of HRV and resting heart-rate history are available.

> **Tip:** Pull down anywhere on the Dashboard to force-refresh all metrics from HealthKit.

---

## Architecture

```
openFitness/
├── Data/
│   └── HealthKitManager.swift         # HealthKit queries, @Published state, score orchestration
├── Logic/
│   └── PhysiologicalCalculators.swift # Pure, stateless score algorithms
├── Views/
│   ├── DashboardView.swift            # Main screen, Activeness Score card, hero cards
│   ├── RecoveryDetailView.swift
│   ├── SleepDetailView.swift
│   ├── StrainDetailView.swift
│   ├── StressHeartRateDetailView.swift
│   ├── WorkoutDetailView.swift
│   ├── FAQView.swift                  # In-app accordion help screen
│   └── SharedComponents.swift         # Line charts, gauges, ECG viewer, pickers
└── Theme.swift                        # Colour tokens, typography, .glassCard() modifier
```

---

## Score Formulas

### Recovery (0–100%)
```
Z_HRV  = (ln(HRV_today) − μ_lnHRV) / σ_lnHRV
Z_RHR  = (μ_RHR − RHR_today) / σ_RHR
Score  = clamp(50 + (0.6·Z_HRV + 0.4·Z_RHR) × 25, 0, 100)
```

### Strain (0.0–21.0)
```
Strain = 21 × (1 − e^(−0.0035 × eTRIMP))
eTRIMP = Σ (duration_min × zone_multiplier)   // zones 1–5 → multipliers 1–5
```

### Sleep (0–100%)
```
Score = (duration / need)×40 + (deep_min / 90)×30 + (rem_min / 90)×20 + dip_ratio×10
```

### Activeness Score (0–100%, requires calibration)
```
Score = 100 × ( 0.25·S_recovery
              + 0.20·S_strain_balance     // Gaussian centred at strain 11
              + 0.20·S_sleep
              + 0.15·S_activity
              + 0.10·S_hrv_trend          // sigmoid-mapped Z-score
              + 0.10·S_stress_inverse )
```

---

## Privacy

openFitness is **read-only**. It requests HealthKit access solely to display your own data. There are no network requests, analytics, crash-reporting SDKs, or third-party dependencies of any kind. All computation runs on-device.

---

## License

MIT
