# SwaasAI ESP32 Hardware BLE Protocol Specification

## 1. Overview
The SWASTHAI mobile application interfaces with the custom `SwaasAI_ESP32` point-of-care screening device over **Bluetooth Low Energy (BLE)** GATT protocol.

- **Offline-First**: All communication operates locally peer-to-peer between ESP32 and phone.
- **Backend Independence**: FastAPI or remote cloud connections are not required for screening acquisition.
- **Non-Diagnostic**: SwasthAI provides screening risk assessment support, not a clinical diagnosis.

---

## 2. Exact Hardware BLE Contract

```
Device Name:
SwaasAI_ESP32

BLE Service UUID:
12345678-1234-1234-1234-1234567890AB

BLE Characteristic UUID:
12345678-1234-1234-1234-1234567890AC

Properties:
READ + NOTIFY

WRITE:
NOT USED.
```

### Transmission Behavior
- **Production Mode**: The ESP32 sends **ONE** complete packet when a patient screening test finishes.
- **READ Flow**: Flutter can explicitly request the latest screening result.
- **NOTIFY Flow**: The ESP32 automatically broadcasts the result upon test completion.
- **Debug Mode (1s stream)**: Optional development test mode; production UI does not rely on 1s stream.

---

## 3. BLE Data Packet Specification

### Format
Comma-separated plain text encoded in UTF-8:
```
ID,AIRFLOW,SPO2,COUGH,RISK,STATUS
```

### Examples
- **Complete Test**:
  ```
  R01,42350,97,1860,42,MODERATE\n
  ```
- **Incomplete / Missing Sensor Data**:
  ```
  R02,39120,NA,1735,NA,INCOMPLETE\r\n
  ```

### Field Definitions

| Index | Field | Type | Description | UI Display Label | Valid Range | NA Token |
|---|---|---|---|---|---|---|
| 0 | `ID` | String | Screening record identifier | `Record ID` | Non-empty alphanumeric | N/A |
| 1 | `AIRFLOW` | Integer | Raw pressure-derived sensor feature | `Raw Airflow Feature` | `>= 0` | `NA` -> `null` / `--` |
| 2 | `SPO2` | Integer | Blood oxygen saturation (%) | `SpO₂` | `0` - `100` | `NA` -> `null` / `--` |
| 3 | `COUGH` | Integer | Digital audio feature value | `Cough Signal` | `>= 0` | `NA` -> `null` / `--` |
| 4 | `RISK` | Integer | Calculated risk score | `Risk Score` | `0` - `100` | `NA` -> `null` / `--` |
| 5 | `STATUS` | String | Screening risk category | `Status` | `LOW`, `MODERATE`, `HIGH`, `INCOMPLETE` | N/A |

---

## 4. NA Handling & Safety Rules

1. **Missing Data Preservation**:
   - `NA` is strictly preserved as `null`.
   - Never convert `NA` -> `0`.
   - Never display `SpO₂ = 0` or `Risk = 0` when data is missing.
   - Display `--` or `Not Available`.

2. **Heart Rate Handling**:
   - The BLE packet does not transmit Heart Rate.
   - Heart Rate is displayed as `--` / `Not Available in BLE packet`.
   - Data is never fabricated.

3. **Airflow Feature Neutrality**:
   - Labeled `"Raw Airflow Feature"`.
   - Never labeled `L/s`, `FEV1`, `Peak Expiratory Flow`, or `Clinical Airflow` until physical calibration is conducted.

4. **Cough Feature Neutrality**:
   - Labeled `"Cough Signal"`.
   - Not labeled as a clinically validated cough severity score.

---

## 5. Connection State Machine

```
Disconnected (🔴)
   │
   ▼ startScan()
Scanning (🟡)
   │
   ▼ connect()
Connecting (🟡)
   │
   ▼ discoverServices()
Discovering Services (🟡)
   │
   ├── [Char not found] ──► Error (🔴)
   │
   ▼ [Service & Char matched + NOTIFY subscribed]
Ready (🟢)
   │
   ├── onNotify / read() ──► Receiving Result (🔵) ──► Ready (🟢)
   │
   ▼ disconnect / drop
Disconnected (🔴) / Connection Lost (🔴)
```
