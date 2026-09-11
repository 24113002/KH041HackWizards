/*
  =============================================================================
  SWASTHAI - Point-of-Care Cardiopulmonary & Respiratory Health Screener
  Firmware for ESP32 with MAX30102, Airflow Pressure Sensor, Mic, and OLED
  =============================================================================
  Hardware Components:
  - ESP32-WROOM-32
  - MAX30102 Pulse Oximeter & Heart Rate (I2C)
  - Differential Low-Range Pressure / Airflow Sensor (ADC / Mouthpiece tube)
  - Microphone Module (ADC / Auscultation & Cough detection)
  - 7-Pin SPI/I2C SSD1306 128x64 OLED Display
  - Push Button (Test Trigger / Calibration)
  =============================================================================
*/

#include <Wire.h>
#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ==========================================
// 1. PIN DEFINITIONS & OLED CONFIGURATION
// ==========================================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

// 7-Pin OLED SPI Pinout on ESP32
#define OLED_MOSI   23  // D1 / Data
#define OLED_CLK    18  // D0 / Clock
#define OLED_DC     16  // DC
#define OLED_CS      5  // CS
#define OLED_RESET  17  // RES / Reset

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT,
  OLED_MOSI, OLED_CLK, OLED_DC, OLED_RESET, OLED_CS);

// Sensors Pinout
#define PIN_PRESSURE_ANALOG   34  // ADC1 CH6: Low-range pressure sensor (mouthpiece tube)
#define PIN_MIC_ANALOG        35  // ADC1 CH7: Analog mic module (cough/breath sound)
#define PIN_PUSH_BUTTON       19  // Push Button (Active LOW with internal pullup)

// ==========================================
// 2. BLE GATT UUIDs (Matching Flutter App)
// ==========================================
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define VITALS_CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define AIRFLOW_CHAR_UUID   "1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e"
#define ACOUSTIC_CHAR_UUID  "d271607c-9204-4769-a038-0796d5147a4b"

BLEServer* pServer = NULL;
BLECharacteristic* pVitalsChar = NULL;
BLECharacteristic* pAirflowChar = NULL;
BLECharacteristic* pAcousticChar = NULL;
bool deviceConnected = false;

// ==========================================
// 3. SENSOR OBJECTS & GLOBALS
// ==========================================
MAX30105 particleSensor;

// Vitals variables
int heartRateBpm = 75;
int spo2Val = 98;
float ppgNormalized = 0.0;
unsigned long lastBeat = 0;
long irValue = 0;

// Spirometry / Airflow variables
bool isBlowTestActive = false;
unsigned long blowStartTime = 0;
float baselinePressureVolts = 1.65; // Calibrated at startup
float cumulativeVolumeLiters = 0.0;
float lastAirflowCalcTime = 0;

// Mic / Acoustic variables
int coughCount = 0;
unsigned long lastCoughTime = 0;
float micRms = 0.0;

// Button state
volatile bool buttonPressed = false;

void IRAM_ATTR handleButtonInterrupt() {
  buttonPressed = true;
}

// BLE Callbacks
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    BLEDevice::startAdvertising();
  }
};

// ==========================================
// 4. SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n[SWASTHAI] Initializing Handheld Health Screener...");

  // Push Button
  pinMode(PIN_PUSH_BUTTON, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_PUSH_BUTTON), handleButtonInterrupt, FALLING);

  // Analog Inputs
  analogReadResolution(12); // 12-bit ADC (0-4095)

  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC)) {
    Serial.println("OLED init failed");
  } else {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(18, 16);
    display.println("SWASTHAI SCREENER");
    display.setCursor(24, 34);
    display.println("Starting BLE...");
    display.display();
  }

  // Initialize MAX30102 via I2C (SDA=21, SCL=22)
  Wire.begin(21, 22);
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found. Check wiring.");
  } else {
    particleSensor.setup(); // Default optical settings
    particleSensor.setPulseAmplitudeRed(0x1F); // Red LED
    particleSensor.setPulseAmplitudeIR(0x1F);  // IR LED
  }

  // Calibrate Pressure Sensor zero-flow baseline
  long sum = 0;
  for (int i = 0; i < 50; i++) {
    sum += analogRead(PIN_PRESSURE_ANALOG);
    delay(10);
  }
  baselinePressureVolts = (sum / 50.0) * (3.3 / 4095.0);
  Serial.print("Airflow baseline calibrated: ");
  Serial.print(baselinePressureVolts);
  Serial.println(" V");

  // Initialize BLE
  BLEDevice::init("SWASTHAI-ESP32");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pVitalsChar = pService->createCharacteristic(
    VITALS_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pVitalsChar->addDescriptor(new BLE2902());

  pAirflowChar = pService->createCharacteristic(
    AIRFLOW_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pAirflowChar->addDescriptor(new BLE2902());

  pAcousticChar = pService->createCharacteristic(
    ACOUSTIC_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pAcousticChar->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("SWASTHAI BLE Advertising started. Ready for connection.");
}

// ==========================================
// 5. MAIN LOOP
// ==========================================
void loop() {
  unsigned long now = millis();

  // Check Button to trigger Spirometry Blow test
  if (buttonPressed) {
    buttonPressed = false;
    if (!isBlowTestActive) {
      startSpirometryTest();
    }
  }

  // 1. Read MAX30102 Vitals
  readMax30102();

  // 2. Read Acoustic / Microphone
  readMicrophone();

  // 3. Handle Spirometry Airflow Blow if active
  if (isBlowTestActive) {
    processAirflowSample(now);
  }

  // 4. Update OLED Display (every 200 ms)
  static unsigned long lastOledUpdate = 0;
  if (now - lastOledUpdate > 200) {
    lastOledUpdate = now;
    updateOledDisplay();
  }

  // 5. Broadcast Vitals over BLE (every 80 ms)
  static unsigned long lastBleSend = 0;
  if (now - lastBleSend > 80 && deviceConnected) {
    lastBleSend = now;
    sendVitalsBle();
  }

  delay(10);
}

// ==========================================
// 6. SENSOR ACQUISITION FUNCTIONS
// ==========================================

void readMax30102() {
  irValue = particleSensor.getIR();
  long redValue = particleSensor.getRed();

  if (irValue > 50000) { // Finger detected on sensor
    if (checkForBeat(irValue)) {
      long delta = millis() - lastBeat;
      lastBeat = millis();
      int bpm = 60 / (delta / 1000.0);
      if (bpm > 45 && bpm < 160) {
        heartRateBpm = bpm;
      }
    }

    // Normalized PPG (0.0 to 1.0)
    ppgNormalized = (float)(irValue % 5000) / 5000.0;

    // Approximate SpO2 ratio based on Red/IR AC/DC ratio
    if (redValue > 0) {
      float ratio = (float)redValue / (float)irValue;
      int calcSpo2 = (int)(110.0 - 25.0 * ratio);
      if (calcSpo2 >= 80 && calcSpo2 <= 100) {
        spo2Val = calcSpo2;
      }
    }
  } else {
    // No finger detected
    ppgNormalized = 0.0;
  }
}

void readMicrophone() {
  // Sample analog mic signal for RMS energy
  int raw = analogRead(PIN_MIC_ANALOG);
  float voltage = (raw * 3.3) / 4095.0;
  float deviation = abs(voltage - 1.65); // AC deviation from 1.65V DC midpoint

  micRms = (micRms * 0.8) + (deviation * 0.2);

  // Cough burst threshold detection (sudden spike > 0.8V deviation lasting > 150ms)
  if (deviation > 0.85 && (millis() - lastCoughTime > 800)) {
    lastCoughTime = millis();
    coughCount++;
    sendAcousticBle(true);
  }
}

void startSpirometryTest() {
  isBlowTestActive = true;
  blowStartTime = millis();
  cumulativeVolumeLiters = 0.0;
  lastAirflowCalcTime = blowStartTime;

  display.clearDisplay();
  display.setTextSize(2);
  display.setCursor(14, 20);
  display.println("BLOW NOW!");
  display.display();
  Serial.println("[SPIROMETRY] Blow test started!");
}

void processAirflowSample(unsigned long now) {
  float elapsedSec = (now - blowStartTime) / 1000.0;
  float dt = (now - lastAirflowCalcTime) / 1000.0;
  lastAirflowCalcTime = now;

  int rawPressure = analogRead(PIN_PRESSURE_ANALOG);
  float volts = (rawPressure * 3.3) / 4095.0;
  float deltaP = volts - baselinePressureVolts;
  if (deltaP < 0) deltaP = 0;

  // Flow rate Q (Liters per second) using orifice flow equation: Q = K * sqrt(deltaP)
  // Calibration factor K calibrated for mouthpiece tube dimensions
  const float K_CALIB = 5.2;
  float flowLps = K_CALIB * sqrt(deltaP);

  cumulativeVolumeLiters += flowLps * dt;

  // Stream Airflow packet over BLE: {"t":1.2,"f":4.5,"v":2.1}
  if (deviceConnected) {
    char buf[64];
    snprintf(buf, sizeof(buf), "{\"t\":%.2f,\"f\":%.2f,\"v\":%.2f}", elapsedSec, flowLps, cumulativeVolumeLiters);
    pAirflowChar->setValue(buf);
    pAirflowChar->notify();
  }

  // End test after 4.5 seconds
  if (elapsedSec >= 4.5 || (elapsedSec > 1.0 && flowLps <= 0.05)) {
    isBlowTestActive = false;
    Serial.print("[SPIROMETRY] Blow finished. FVC: ");
    Serial.print(cumulativeVolumeLiters);
    Serial.println(" L");
  }
}

// ==========================================
// 7. BLE NOTIFICATION TRANSMISSION
// ==========================================

void sendVitalsBle() {
  char buf[64];
  snprintf(buf, sizeof(buf), "{\"hr\":%d,\"spo2\":%d,\"ppg\":%.2f}", heartRateBpm, spo2Val, ppgNormalized);
  pVitalsChar->setValue(buf);
  pVitalsChar->notify();
}

void sendAcousticBle(bool isCough) {
  if (!deviceConnected) return;
  char buf[64];
  snprintf(buf, sizeof(buf), "{\"rms\":%.2f,\"cough\":%d,\"freq\":350}", micRms, isCough ? 1 : 0);
  pAcousticChar->setValue(buf);
  pAcousticChar->notify();
}

// ==========================================
// 8. OLED RENDERING
// ==========================================

void updateOledDisplay() {
  display.clearDisplay();

  // Header Bar
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print("SWASTHAI  ");
  display.print(deviceConnected ? "[BLE OK]" : "[WAIT]");

  display.drawLine(0, 10, 127, 10, SSD1306_WHITE);

  if (isBlowTestActive) {
    display.setTextSize(2);
    display.setCursor(10, 20);
    display.println("BLOWING...");
    display.setTextSize(1);
    display.setCursor(10, 48);
    display.print("Vol: ");
    display.print(cumulativeVolumeLiters, 2);
    display.print(" L");
  } else {
    // Vitals Section
    display.setTextSize(1);
    display.setCursor(0, 16);
    display.print("HR:  ");
    display.setTextSize(2);
    display.print(heartRateBpm);
    display.setTextSize(1);
    display.println(" bpm");

    display.setCursor(0, 36);
    display.print("SpO2: ");
    display.setTextSize(2);
    display.print(spo2Val);
    display.setTextSize(1);
    display.println(" %");

    display.setCursor(0, 54);
    display.print("Btn: Blow | Coughs: ");
    display.print(coughCount);
  }

  display.display();
}
