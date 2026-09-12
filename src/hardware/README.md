# SWASTHAI ESP32 Firmware & Hardware Wiring Guide

This guide details the hardware assembly, pinouts, and flashing instructions for the **SWASTHAI Handheld Health Screener** running on the ESP32.

---

## 1. Hardware Bill of Materials (BOM)

| Component | Function | Interface / Pin |
|---|---|---|
| **ESP32 DevKit v1** (30 or 38-pin) | Main Controller & BLE Server | Micro-USB / 3.3V Logic |
| **MAX30102** Module | Pulse Oximetry & Heart Rate (PPG) | I2C (SDA, SCL) |
| **Low-Range Differential Pressure Sensor** | Airflow measurement (Spirometry) | Analog ADC (GPIO 34) |
| **Analog Microphone Module** | Cough sound & wheeze auscultation | Analog ADC (GPIO 35) |
| **7-Pin 0.96" SSD1306 OLED** | On-device display (vitals & blow prompt) | SPI (MOSI, CLK, DC, CS, RES) |
| **Tactile Push Button** | Trigger forced exhalation blow test | Digital GPIO (GPIO 19) |
| **Mouthpiece & Plastic Tube** | Venturi / differential airflow tube | Connected to pressure ports |

---

## 2. Wiring & Pinout Table

### A. 7-Pin SPI OLED (SSD1306 128x64)
| OLED Pin | ESP32 Pin | Note |
|---|---|---|
| **GND** | GND | Ground |
| **VCC** | 3.3V | Power (Do not connect to 5V) |
| **D0 / CLK** | GPIO 18 | SPI Clock (SCK) |
| **D1 / MOSI**| GPIO 23 | SPI Data (MOSI) |
| **RES** | GPIO 17 | Reset |
| **DC** | GPIO 16 | Data/Command |
| **CS** | GPIO 5 | Chip Select |

### B. MAX30102 Pulse Oximeter
| MAX30102 Pin | ESP32 Pin | Note |
|---|---|---|
| **VIN** | 3.3V | Power |
| **GND** | GND | Ground |
| **SDA** | GPIO 21 | I2C Data |
| **SCL** | GPIO 22 | I2C Clock |
| **INT** | NC (Not connected) | Optional |

### C. Differential Airflow Pressure Sensor (e.g., MP3V5050DP / MPX5010DP)
| Sensor Pin | ESP32 Pin | Note |
|---|---|---|
| **Vs** | 3.3V or 5V | Sensor supply voltage |
| **GND** | GND | Ground |
| **Vout** | GPIO 34 | Analog ADC1 CH6 |
| **P1 Port** | Plastic tube to mouthpiece | Measures positive dynamic pressure |
| **P2 Port** | Ambient air | Reference atmospheric port |

### D. Microphone Module (MAX9814 / Basic Electret)
| Mic Pin | ESP32 Pin | Note |
|---|---|---|
| **VCC** | 3.3V | Power |
| **GND** | GND | Ground |
| **OUT** | GPIO 35 | Analog ADC1 CH7 |

### E. Tactile Push Button
| Button Pin | ESP32 Pin | Note |
|---|---|---|
| **Terminal 1** | GPIO 19 | Configured with internal pullup (`INPUT_PULLUP`) |
| **Terminal 2** | GND | Pressing pulls pin LOW |

---

## 3. Arduino IDE Setup & Required Libraries

1. Install the **ESP32 Board Support Package**:
   - In Arduino IDE: `File -> Preferences -> Additional Board Manager URLs`:
     `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Go to `Tools -> Board -> Boards Manager`, search for `esp32` by Espressif Systems and click **Install**.

2. Install the required libraries via `Tools -> Manage Libraries...`:
   - **`Adafruit SSD1306`** (by Adafruit)
   - **`Adafruit GFX Library`** (by Adafruit)
   - **`SparkFun MAX3010x Pulse and Proximity Sensor Library`** (by SparkFun)

3. Open `swasthai_esp32_firmware.ino` in Arduino IDE.
4. Select board: **ESP32 Dev Module**.
5. Upload Speed: `921600` or `115200`.
6. Select your COM Port and click **Upload**.

---

## 4. Bluetooth Low Energy (BLE) GATT Architecture

The ESP32 advertises under device name: **`SWASTHAI-ESP32`**.

- **Primary Health Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
  - **Vitals Characteristic** (`beb5483e-36e1-4688-b7f5-ea07361b26a8`):
    Broadcasts ASCII JSON at 12 Hz: `{"hr":75,"spo2":98,"ppg":0.52}`
  - **Airflow / Spirometry Characteristic** (`1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e`):
    Broadcasts exhalation curve at 20 Hz during blow: `{"t":1.20,"f":4.50,"v":2.10}`
  - **Acoustic / Mic Characteristic** (`d271607c-9204-4769-a038-0796d5147a4b`):
    Broadcasts cough flags & loudness: `{"rms":0.45,"cough":1,"freq":350}`

---

## 5. Pairing with the SWASTHAI Flutter App

1. Launch the **SWASTHAI** app on your Android/iOS/Desktop device.
2. In the top status card, tap the menu (`⋮`) and select **"Switch to Real BLE Hardware"** (or tap **"Scan for ESP32"**).
3. The app scans and lists `SWASTHAI-ESP32`.
4. Tap **Connect**.
5. The OLED display on the ESP32 updates to `[BLE OK]`.
6. Live vitals, real-time exhalation curves, and cough detection streams will now reflect live on the app!
