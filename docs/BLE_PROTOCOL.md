# SWASTHAI BLE Communication Protocol Specification

## 1. Overview
The SWASTHAI mobile application communicates with the custom ESP32 screening hardware over **Bluetooth Low Energy (BLE)** GATT services. Communication is **100% offline**, requiring zero internet, cloud connectivity, or external servers.

---

## 2. Hardware BLE Contract

> **IMPORTANT**: Hardware UUIDs and payload formats are defined in `lib/config/ble_config.dart` and the matching ESP32 firmware in `esp32_firmware/swasthai_esp32_firmware.ino`.

### Device Identification
- **Target Device Name**: `SWASTHAI_ESP32`
- **Supported Prefixes**: `SWASTHAI`, `SwasthAI`, `SWASTH`

### Primary GATT Service
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

### Characteristics Specification

| Characteristic | UUID | Properties | Purpose | Payload Schema |
|---|---|---|---|---|
| **Vitals Stream** | `beb5483e-36e1-4688-b7f5-ea07361b26a8` | `NOTIFY`, `READ` | Stream pulse oximeter data (SpO2, Heart Rate, PPG curve) | `{"hr":82,"spo2":97,"ppg":0.52}` |
| **Airflow / Spirometry** | `1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e` | `NOTIFY`, `READ` | Stream differential pressure & flow rate during forced exhalation | `{"t":1.20,"f":4.50,"v":2.10,"p":1.84}` |
| **Acoustic / Auscultation** | `d271607c-9204-4769-a038-0796d5147a4b` | `NOTIFY`, `READ` | Stream RMS loudness energy and cough detection events | `{"rms":0.72,"cough":1,"freq":350}` |
| **Command / Control** | `00000000-0000-0000-0000-000000000000` | `WRITE` | Firmware trigger / calibration placeholder | `<FIRMWARE_COMMAND>` |

---

## 3. Payload Formats & Field Validations

### 1. Composite / Multi-Modal Payload
```json
{
  "spo2": 97,
  "heart_rate": 82,
  "pressure": 1.84,
  "cough_activity": 0.72
}
```

### 2. Vitals Payload (MAX30102)
Emitted at **12.5 Hz (~80 ms interval)**:
```json
{
  "hr": 82,
  "spo2": 97,
  "ppg": 0.52
}
```
- `hr` (int): Heart rate in beats per minute (Valid range: `30` - `220` bpm).
- `spo2` (int): Oxygen saturation percentage (Valid range: `50` - `100`%).
- `ppg` (float): Normalized photoplethysmogram AC amplitude (`0.0` to `1.0`).

### 3. Airflow Payload (Differential Pressure Orifice)
Emitted at **20 Hz (~50 ms interval)** during active blow maneuver:
```json
{
  "t": 1.25,
  "f": 5.40,
  "v": 2.65,
  "p": 1.84
}
```
- `t` (float): Elapsed blow duration in seconds (`0.0` - `60.0` s).
- `f` (float): Expiratory flow rate in Liters per second (`0.0` - `25.0` L/s).
- `v` (float): Cumulative integrated volume in Liters (`0.0` - `12.0` L).
- `p` (float): Differential pressure in kPa (`0.0` - `20.0` kPa).

### 4. Acoustic / Cough Detection Payload (Microphone Module)
Emitted on acoustic RMS sampling or cough trigger event:
```json
{
  "rms": 0.72,
  "cough": 1,
  "freq": 350
}
```
- `rms` (float): Root mean square sound loudness (`0.0` - `1.0`).
- `cough` (int/bool): `1` if a transient cough burst is detected, `0` otherwise.
- `freq` (float): Peak dominant frequency in Hz.

---

## 4. Error Handling & Parsing Safety
1. **Malformed Packets**: If JSON decoding fails, the packet is ignored without crashing the application.
2. **Missing Fields**: Omitted fields are retained as `null` in `SensorReading`, ensuring no artificial `0` substitutions.
3. **Out-of-Range Metrics**: Values exceeding physiological bounds (e.g. SpO2 > 100% or < 50%) are rejected by `SensorDataParser`.
4. **Disconnections**: In the event of an unexpected hardware disconnect, the active screening wizard displays a non-intrusive recovery banner and enters a paused state without inventing fake data.

---

## 5. Security & Privacy
- **Zero Patient Data on BLE**: Patient demographics, names, IDs, and village locations are never transmitted to the ESP32.
- **Local Isolation**: The ESP32 is solely a peripheral data provider; all clinical evaluation and history remain on the mobile device.
