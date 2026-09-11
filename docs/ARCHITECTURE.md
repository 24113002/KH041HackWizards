# SwasthAI Architecture & Local-First Data Workflow

## Overview
SwasthAI is an **offline-first**, mobile health screening application designed for rural cardiopulmonary and respiratory risk triage. The application operates entirely locally on-device without requiring internet connectivity, cloud authentication, or remote backend servers.

---

## 1. Data Models

### `Patient`
Represents demographic and reference health information:
- `id` (UUID String)
- `fullName` (String)
- `age` (int)
- `gender` (Gender: male, female, other)
- `village` (String)
- `occupation` (String)
- `smokingStatus` (String: Non-smoker, Former smoker, Current smoker)
- `createdAt` & `updatedAt` (DateTime)

### `ScreeningSession`
Tracks the lifecycle of a patient's screening session:
- `id` (UUID String)
- `patientId` (String foreign key to Patient)
- `startedAt` (DateTime)
- `completedAt` (DateTime?, nullable)
- `status` (ScreeningStatus: `inProgress`, `completed`, `cancelled`)
- `riskScore` (int?, nullable)
- `riskCategory` (String?, nullable)

### `SensorReading`
Nullable sensor reading model for incoming BLE packets:
- `id` (String)
- `screeningId` (String)
- `timestamp` (DateTime)
- `spo2` (int?, nullable — `null` indicates unavailable, never substitute `0%`)
- `heartRate` (int?, nullable)
- `pressure` (double?, nullable)
- `coughActivity` (double?, nullable)

### `QuestionnaireResponse`
Captures clinical symptoms and environmental risk factors:
- `screeningId` (String)
- `smokingStatus` (String)
- `yearsSmoked` (double)
- `cigarettesPerDay` (int)
- `biomassExposure` (String)
- `breathlessness` (int - mMRC grade 0-4)
- `chronicCough` (bool)
- `phlegm` (bool)
- `wheezing` (bool)
- `recurrentRespiratoryProblems` (bool)

### `RiskResult`
Holds risk engine output and clinical screening recommendations:
- `screeningId` (String)
- `riskScore` (int: 0 to 100)
- `riskCategory` (String: Low Risk, Moderate Risk, High Risk, Critical Risk)
- `contributingFactors` (List<String>)
- `recommendation` (String)
- `createdAt` (DateTime)
- Mandatory non-diagnostic disclaimer notice.

---

## 2. Layered Clean Architecture

```
┌────────────────────────────────────────────────────────┐
│                        UI Layer                        │
│   (HomeScreen, PatientsScreen, PatientDetailsScreen,   │
│   DeviceConnectionScreen, LiveScreeningScreen, Result) │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                    State Management                    │
│   (PatientProvider, CurrentScreeningController,       │
│           ScreeningHistoryController)                 │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                    Service Abstraction                 │
│      (BleService: RealBleService / MockBleService)     │
│      (SensorDataParser: Raw GATT bytes -> Models)      │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                   Repository Layer                     │
│  (PatientRepository -> LocalPatientRepository,         │
│   ScreeningRepository -> LocalScreeningRepository)     │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                  Local Data Persistence                │
│       (SQLite / sqflite FFI offline database)          │
└────────────────────────────────────────────────────────┘
```

---

## 3. Bluetooth Low Energy (BLE) Integration Architecture

```
ESP32 Hardware
  │ (MAX30102 / Differential Pressure / Mic)
  ▼
Bluetooth Low Energy (GATT Server)
  │ (flutter_blue_plus)
  ▼
RealBleService (implements BleService)  <─── OR ───>  MockBleService (implements BleService)
  │
  ▼
SensorDataParser (Decodes UTF-8 JSON, validates ranges, handles missing fields)
  │
  ▼
SensorReading & Vitals Models
  │
  ▼
Screening State / LiveScreeningScreen / Vitals UI
```

### Switching Between Real Hardware & Simulator
- **Real BLE Mode (`RealBleService`)**: Uses `flutter_blue_plus` to scan for `SWASTHAI_ESP32`, discovers service UUID `4fafc201-1fb5-459e-8fcc-c5c9c331914b`, and subscribes to Vitals, Airflow, and Acoustic GATT notifications.
- **Simulator Mode (`MockBleService`)**: Generates physiological PPG waveforms, SpO2 jitter (96-98%), spirometry blow curves, and cough detection for instant offline UI testing without physical hardware.
- **Unified Manager (`AppBleService`)**: Implements `BleService` by delegating to either `RealBleService` or `MockBleService` based on user selection or runtime configuration.

---

## 4. Non-Diagnostic Medical Notice
> **Disclaimer**: SwasthAI is a screening-support application designed for point-of-care triage and risk stratification. It is NOT a diagnostic medical device. Confirmatory clinical evaluation and formal laboratory/spirometry diagnostic testing must be conducted by a qualified medical professional.
