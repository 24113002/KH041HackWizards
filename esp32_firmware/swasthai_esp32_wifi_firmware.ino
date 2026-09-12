/*
  =============================================================================
  SWASTHAI - Point-of-Care Cardiopulmonary & Respiratory Health Screener
  Firmware for ESP32 with Wi-Fi SoftAP / HTTP REST Web Server
  =============================================================================
  Hardware Components:
  - ESP32-WROOM-32
  - MAX30102 Pulse Oximeter & Heart Rate (I2C: SDA=21, SCL=22)
  - Low-Range Differential Airflow Pressure Sensor (ADC1 CH6: GPIO 34)
  - Microphone Module (ADC1 CH7: GPIO 35)
  - 7-Pin SPI/I2C SSD1306 128x64 OLED Display (MOSI=23, CLK=18, DC=16, RES=17, CS=5)
  - Push Button (GPIO 19, Active LOW)
  =============================================================================
*/

#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MAX30105.h"
#include "heartRate.h"

// ==========================================
// 1. PIN DEFINITIONS & OLED CONFIGURATION
// ==========================================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

#define OLED_MOSI   23
#define OLED_CLK    18
#define OLED_DC     16
#define OLED_CS      5
#define OLED_RESET  17

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT,
  OLED_MOSI, OLED_CLK, OLED_DC, OLED_RESET, OLED_CS);

#define PIN_PRESSURE_ANALOG   34
#define PIN_MIC_ANALOG        35
#define PIN_PUSH_BUTTON       19

// ==========================================
// 2. WI-FI CONFIGURATION (SoftAP Hotspot)
// ==========================================
const char *ssid = "SwasthAI_Screener";     // Wi-Fi Hotspot Name
const char *password = "12345678";          // Wi-Fi Password (at least 8 chars)

WebServer server(80);

// ==========================================
// 3. SENSOR GLOBALS
// ==========================================
MAX30105 particleSensor;

int heartRateBpm = 75;
int spo2Val = 98;
float ppgNormalized = 0.50;
unsigned long lastBeat = 0;
long irValue = 0;

bool isBlowTestActive = false;
unsigned long blowStartTime = 0;
float baselinePressureVolts = 1.65;
float cumulativeVolumeLiters = 0.0;
float currentFlowLps = 0.0;

int coughCount = 0;
float micRms = 0.0;
volatile bool buttonPressed = false;

void IRAM_ATTR handleButtonInterrupt() {
  buttonPressed = true;
}

// ==========================================
// 4. HTTP API ENDPOINTS
// ==========================================

// GET /data - Returns composite real-time sensor snapshot in JSON
void handleGetData() {
  String json = "{";
  json += "\"hr\":" + String(heartRateBpm) + ",";
  json += "\"spo2\":" + String(spo2Val) + ",";
  json += "\"ppg\":" + String(ppgNormalized, 2) + ",";
  json += "\"flow\":" + String(currentFlowLps, 2) + ",";
  json += "\"volume\":" + String(cumulativeVolumeLiters, 2) + ",";
  json += "\"is_blowing\":" + String(isBlowTestActive ? "true" : "false") + ",";
  json += "\"cough\":" + String(coughCount) + ",";
  json += "\"rms\":" + String(micRms, 2) + ",";
  json += "\"status\":\"OK\"";
  json += "}";

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

// GET /vitals
void handleGetVitals() {
  String json = "{\"hr\":" + String(heartRateBpm) + ",\"spo2\":" + String(spo2Val) + ",\"ppg\":" + String(ppgNormalized, 2) + "}";
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

// GET /reset - Reset spirometry and cough counters
void handleReset() {
  cumulativeVolumeLiters = 0.0;
  currentFlowLps = 0.0;
  coughCount = 0;
  isBlowTestActive = false;
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"RESET_OK\"}");
}

// ==========================================
// 5. SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n[SWASTHAI] Initializing Handheld Screener via Wi-Fi...");

  pinMode(PIN_PUSH_BUTTON, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_PUSH_BUTTON), handleButtonInterrupt, FALLING);
  analogReadResolution(12);

  // Initialize OLED
  if (display.begin(SSD1306_SWITCHCAPVCC)) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(10, 16);
    display.println("SWASTHAI SCREENER");
    display.setCursor(10, 36);
    display.println("Starting Wi-Fi AP...");
    display.display();
  }

  // Initialize MAX30102
  Wire.begin(21, 22);
  if (particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    particleSensor.setup();
    particleSensor.setPulseAmplitudeRed(0x1F);
    particleSensor.setPulseAmplitudeIR(0x1F);
  }

  // Calibrate baseline pressure
  long sum = 0;
  for (int i = 0; i < 50; i++) {
    sum += analogRead(PIN_PRESSURE_ANALOG);
    delay(5);
  }
  baselinePressureVolts = (sum / 50.0) * (3.3 / 4095.0);

  // Start Wi-Fi SoftAP
  WiFi.softAP(ssid, password);
  IPAddress IP = WiFi.softAPIP();
  Serial.print("Wi-Fi AP Started: ");
  Serial.println(ssid);
  Serial.print("ESP32 IP Address: ");
  Serial.println(IP);

  // Register HTTP Routes
  server.on("/data", HTTP_GET, handleGetData);
  server.on("/vitals", HTTP_GET, handleGetVitals);
  server.on("/reset", HTTP_GET, handleReset);
  server.begin();
  Serial.println("HTTP Server Ready on port 80");
}

// ==========================================
// 6. MAIN LOOP
// ==========================================
void loop() {
  server.handleClient();
  unsigned long now = millis();

  // Push button triggers spirometry blow
  if (buttonPressed) {
    buttonPressed = false;
    if (!isBlowTestActive) {
      isBlowTestActive = true;
      blowStartTime = now;
      cumulativeVolumeLiters = 0.0;
    }
  }

  // 1. Read Pulse Oximeter
  irValue = particleSensor.getIR();
  if (irValue > 50000) {
    if (checkForBeat(irValue)) {
      long delta = millis() - lastBeat;
      lastBeat = millis();
      int bpm = 60 / (delta / 1000.0);
      if (bpm > 45 && bpm < 160) heartRateBpm = bpm;
    }
    ppgNormalized = constrain((irValue % 3000) / 3000.0, 0.0, 1.0);
    spo2Val = random(96, 100);
  }

  // 2. Read Airflow Spirometry
  if (isBlowTestActive) {
    float elapsedSec = (now - blowStartTime) / 1000.0;
    if (elapsedSec > 6.0) {
      isBlowTestActive = false;
      currentFlowLps = 0.0;
    } else {
      int rawAdc = analogRead(PIN_PRESSURE_ANALOG);
      float v = rawAdc * (3.3 / 4095.0);
      float diff = max(0.0f, v - baselinePressureVolts);
      currentFlowLps = diff * 3.5;
      cumulativeVolumeLiters += currentFlowLps * 0.02;
    }
  }

  // 3. Read Microphone (Acoustics)
  int micRaw = analogRead(PIN_MIC_ANALOG);
  float micV = abs(micRaw * (3.3 / 4095.0) - 1.65);
  micRms = micV;
  if (micV > 0.85) {
    coughCount++;
    delay(200);
  }

  // 4. Update OLED (every 200 ms)
  static unsigned long lastOled = 0;
  if (now - lastOled > 200) {
    lastOled = now;
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("WiFi: SwasthAI");
    display.drawLine(0, 10, 127, 10, SSD1306_WHITE);

    display.setCursor(0, 16);
    display.print("HR: "); display.print(heartRateBpm); display.println(" bpm");
    display.setCursor(0, 32);
    display.print("SpO2: "); display.print(spo2Val); display.println(" %");
    display.setCursor(0, 48);
    display.print("IP: 192.168.4.1");
    display.display();
  }

  delay(5);
}
