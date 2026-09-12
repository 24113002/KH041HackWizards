
#include <Wire.h>
#include <SPI.h>
#include <U8g2lib.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <driver/i2s.h>
#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

// =====================================================
// PIN DEFINITIONS
// =====================================================

// ---------- OLED SPI ----------
#define OLED_SCK   13
#define OLED_MOSI  23
#define OLED_CS    5
#define OLED_DC    4
#define OLED_RST   2

// ---------- MAX30102 I2C ----------
#define MAX_SDA    21
#define MAX_SCL    22

// ---------- HX710B ----------
#define HX_SCK     18
#define HX_OUT     19

// ---------- INMP441 ----------
#define I2S_SCK    26
#define I2S_WS     25
#define I2S_SD     33

// ---------- BUTTON ----------
#define BUTTON_PIN 27

// ---------- I2S ----------
#define I2S_PORT I2S_NUM_0

// =====================================================
// OLED
// =====================================================

U8G2_SH1106_128X64_NONAME_F_4W_SW_SPI oled(
  U8G2_R0,
  OLED_SCK,
  OLED_MOSI,
  OLED_CS,
  OLED_DC,
  OLED_RST
);

// =====================================================
// MAX30102
// =====================================================

MAX30105 maxSensor;

bool maxAvailable = false;

// =====================================================
// MICROPHONE
// =====================================================

bool microphoneReady = false;

// =====================================================
// SENSOR RESULTS
// =====================================================

long airflowFeature = 0;
long coughFeature = 0;

int spo2Value = 0;
int heartRateValue = 0;

bool spo2Valid = false;
bool heartRateValid = false;

// =====================================================
// OLED MESSAGE
// =====================================================

void showMessage(
  const char *line1,
  const char *line2,
  const char *line3
) {
  oled.clearBuffer();

  oled.setFont(u8g2_font_6x12_tf);

  oled.drawStr(2, 15, line1);
  oled.drawStr(2, 35, line2);
  oled.drawStr(2, 55, line3);

  oled.sendBuffer();
}

// =====================================================
// WAIT FOR BUTTON
// =====================================================

void waitForButton(const char *message) {

  showMessage(
    message,
    "Press button",
    "when ready"
  );

  Serial.println();
  Serial.println(message);
  Serial.println("Press button when ready.");

  while (digitalRead(BUTTON_PIN) == LOW) {
    delay(20);
  }

  while (digitalRead(BUTTON_PIN) == HIGH) {
    delay(20);
  }

  delay(100);

  while (digitalRead(BUTTON_PIN) == LOW) {
    delay(20);
  }

  delay(300);
}

// =====================================================
// COUNTDOWN
// =====================================================

void countdown(const char *name) {

  char text[22];

  for (int i = 3; i >= 1; i--) {

    sprintf(
      text,
      "Starting in %d",
      i
    );

    showMessage(
      name,
      text,
      "GET READY"
    );

    Serial.print(name);
    Serial.print(" : ");
    Serial.println(text);

    delay(1000);
  }

  showMessage(
    name,
    "START NOW!",
    ""
  );

  Serial.println("START NOW!");

  delay(500);
}

// =====================================================
// HX710B READ
// =====================================================

long readHX710B() {

  unsigned long startTime = millis();

  while (digitalRead(HX_OUT) == HIGH) {

    if (millis() - startTime > 500) {
      return 0;
    }
  }

  long value = 0;

  for (int i = 0; i < 24; i++) {

    digitalWrite(HX_SCK, HIGH);

    delayMicroseconds(1);

    value <<= 1;

    digitalWrite(HX_SCK, LOW);

    delayMicroseconds(1);

    if (digitalRead(HX_OUT)) {
      value++;
    }
  }

  digitalWrite(HX_SCK, HIGH);
  delayMicroseconds(1);

  digitalWrite(HX_SCK, LOW);
  delayMicroseconds(1);

  if (value & 0x800000) {
    value |= 0xFF000000;
  }

  return value;
}

// =====================================================
// PRESSURE CALIBRATION
// =====================================================

void calibratePressure() {

  showMessage(
    "PRESSURE SENSOR",
    "Keep tube free",
    "Calibrating"
  );

  Serial.println();
  Serial.println("Calibrating HX710B...");
  Serial.println("Do NOT blow.");

  long total = 0;
  int valid = 0;

  for (int i = 0; i < 20; i++) {

    long reading = readHX710B();

    if (reading != 0) {
      total += reading;
      valid++;
    }

    delay(50);
  }

  if (valid > 0) {

    long baseline = total / valid;

    Serial.print("Pressure baseline = ");
    Serial.println(baseline);

  } else {

    Serial.println("WARNING: No HX710B readings.");
  }

  delay(1000);
}

// =====================================================
// AIRFLOW TEST
// =====================================================

void performAirflowTest() {

  waitForButton("AIRFLOW TEST");

  countdown("AIRFLOW");

  Serial.println();
  Serial.println("========================");
  Serial.println("AIRFLOW TEST");
  Serial.println("========================");

  showMessage(
    "AIRFLOW",
    "Keep tube free",
    "Calibrating"
  );

  Serial.println("Taking airflow baseline...");

  long total = 0;
  int valid = 0;

  for (int i = 0; i < 15; i++) {

    long reading = readHX710B();

    if (reading != 0) {

      total += reading;
      valid++;
    }

    delay(50);
  }

  long baseline = 0;

  if (valid > 0) {
    baseline = total / valid;
  }

  Serial.print("Baseline = ");
  Serial.println(baseline);

  showMessage(
    "AIRFLOW",
    "BLOW NOW!",
    "5 seconds"
  );

  Serial.println("BLOW NOW!");

  long maximumDifference = 0;
  int validReadings = 0;

  unsigned long startTime = millis();

  while (millis() - startTime < 5000) {

    long raw = readHX710B();

    if (raw != 0) {

      long difference = labs(raw - baseline);

      if (difference > maximumDifference) {
        maximumDifference = difference;
      }

      validReadings++;

      Serial.print("Pressure = ");
      Serial.println(raw);
    }

    delay(50);
  }

  airflowFeature = maximumDifference;

  Serial.println();
  Serial.println("---- AIRFLOW RESULT ----");

  Serial.print("Airflow feature = ");
  Serial.println(airflowFeature);

  Serial.print("Valid readings = ");
  Serial.println(validReadings);

  char result[22];

  sprintf(
    result,
    "Feature: %ld",
    airflowFeature
  );

  if (validReadings > 0) {

    showMessage(
      "AIRFLOW COMPLETE",
      result,
      "Press button"
    );

  } else {

    showMessage(
      "AIRFLOW ERROR",
      "No readings",
      "Check HX710B"
    );
  }

  delay(1500);

  waitForButton("NEXT: SpO2");
}

// =====================================================
// MAX30102 SETUP
// =====================================================

void setupMAX30102() {

  Wire.begin(
    MAX_SDA,
    MAX_SCL
  );

  Serial.println("Checking MAX30102...");

  if (
    maxSensor.begin(
      Wire,
      I2C_SPEED_STANDARD
    )
  ) {

    maxAvailable = true;

    Serial.println("MAX30102 FOUND");

    maxSensor.setup(
      60,
      4,
      2,
      100,
      411,
      4096
    );

    maxSensor.setPulseAmplitudeRed(0x1F);

    maxSensor.setPulseAmplitudeIR(0x1F);

    maxSensor.setPulseAmplitudeGreen(0);

  } else {

    maxAvailable = false;

    Serial.println("MAX30102 NOT FOUND");
  }
}

// =====================================================
// SpO2 TEST
// =====================================================

void performSpO2Test() {

  waitForButton("SpO2 TEST");

  countdown("SpO2");

  Serial.println();
  Serial.println("========================");
  Serial.println("SpO2 TEST");
  Serial.println("========================");

  if (!maxAvailable) {

    showMessage(
      "SpO2 ERROR",
      "MAX30102 missing",
      "Check wiring"
    );

    Serial.println("MAX30102 unavailable.");

    spo2Valid = false;
    heartRateValid = false;

    delay(2500);

    return;
  }

  showMessage(
    "SpO2 TEST",
    "PLACE FINGER",
    "KEEP STILL"
  );

  Serial.println("Place finger on MAX30102.");

  delay(1000);

  #define SPO2_BUFFER_SIZE 100

  uint32_t irBuffer[SPO2_BUFFER_SIZE];
  uint32_t redBuffer[SPO2_BUFFER_SIZE];

  int collected = 0;

  Serial.println("Collecting samples...");

  while (collected < SPO2_BUFFER_SIZE) {

    maxSensor.check();

    while (
      maxSensor.available() &&
      collected < SPO2_BUFFER_SIZE
    ) {

      redBuffer[collected] =
        maxSensor.getFIFORed();

      irBuffer[collected] =
        maxSensor.getFIFOIR();

      maxSensor.nextSample();

      collected++;

      Serial.print("Sample ");
      Serial.print(collected);

      Serial.print(" IR=");
      Serial.print(irBuffer[collected - 1]);

      Serial.print(" RED=");
      Serial.println(redBuffer[collected - 1]);
    }

    delay(10);
  }

  int32_t calculatedSpO2 = 0;
  int8_t validSpO2 = 0;

  int32_t calculatedHR = 0;
  int8_t validHR = 0;

  maxim_heart_rate_and_oxygen_saturation(
    irBuffer,
    SPO2_BUFFER_SIZE,
    redBuffer,
    &calculatedSpO2,
    &validSpO2,
    &calculatedHR,
    &validHR
  );

  if (
    validSpO2 &&
    calculatedSpO2 >= 70 &&
    calculatedSpO2 <= 100
  ) {

    spo2Value = calculatedSpO2;
    spo2Valid = true;

  } else {

    spo2Value = 0;
    spo2Valid = false;
  }

  if (
    validHR &&
    calculatedHR >= 30 &&
    calculatedHR <= 220
  ) {

    heartRateValue = calculatedHR;
    heartRateValid = true;

  } else {

    heartRateValue = 0;
    heartRateValid = false;
  }

  Serial.println();
  Serial.println("---- SpO2 RESULT ----");

  if (spo2Valid) {

    Serial.print("SpO2 = ");
    Serial.print(spo2Value);
    Serial.println(" %");

  } else {

    Serial.println("SpO2 = INVALID");
  }

  if (heartRateValid) {

    Serial.print("Heart Rate = ");
    Serial.print(heartRateValue);
    Serial.println(" BPM");

  } else {

    Serial.println("Heart Rate = INVALID");
  }

  char line2[22];
  char line3[22];

  if (spo2Valid) {

    sprintf(
      line2,
      "SpO2: %d %%",
      spo2Value
    );

  } else {

    sprintf(
      line2,
      "SpO2: INVALID"
    );
  }

  if (heartRateValid) {

    sprintf(
      line3,
      "HR: %d BPM",
      heartRateValue
    );

  } else {

    sprintf(
      line3,
      "HR: INVALID"
    );
  }

  showMessage(
    "SpO2 COMPLETE",
    line2,
    line3
  );

  delay(2000);

  waitForButton("NEXT: AIRFLOW");
}

// =====================================================
// MICROPHONE SETUP
// =====================================================

void setupMicrophone() {

  i2s_config_t i2s_config = {

    .mode =
      (i2s_mode_t)(
        I2S_MODE_MASTER |
        I2S_MODE_RX
      ),

    .sample_rate = 16000,

    .bits_per_sample =
      I2S_BITS_PER_SAMPLE_32BIT,

    .channel_format =
      I2S_CHANNEL_FMT_ONLY_LEFT,

    .communication_format =
      I2S_COMM_FORMAT_I2S,

    .intr_alloc_flags = 0,

    .dma_buf_count = 8,

    .dma_buf_len = 64,

    .use_apll = false,

    .tx_desc_auto_clear = false,

    .fixed_mclk = 0
  };

  i2s_pin_config_t pin_config = {

    .bck_io_num = I2S_SCK,

    .ws_io_num = I2S_WS,

    .data_out_num =
      I2S_PIN_NO_CHANGE,

    .data_in_num = I2S_SD
  };

  esp_err_t result;

  result =
    i2s_driver_install(
      I2S_PORT,
      &i2s_config,
      0,
      NULL
    );

  if (result != ESP_OK) {

    Serial.println(
      "INMP441 driver ERROR"
    );

    microphoneReady = false;

    return;
  }

  result =
    i2s_set_pin(
      I2S_PORT,
      &pin_config
    );

  if (result != ESP_OK) {

    Serial.println(
      "INMP441 pin ERROR"
    );

    microphoneReady = false;

  } else {

    Serial.println(
      "INMP441 READY"
    );

    microphoneReady = true;
  }
}

// =====================================================
// MICROPHONE READ
// =====================================================

long readMicrophone() {

  int32_t samples[64];

  size_t bytesRead = 0;

  esp_err_t result =
    i2s_read(
      I2S_PORT,
      samples,
      sizeof(samples),
      &bytesRead,
      100 / portTICK_PERIOD_MS
    );

  if (result != ESP_OK) {
    return 0;
  }

  int sampleCount =
    bytesRead / sizeof(int32_t);

  if (sampleCount <= 0) {
    return 0;
  }

  uint64_t total = 0;

  for (int i = 0; i < sampleCount; i++) {

    int32_t value =
      samples[i] >> 14;

    total += abs(value);
  }

  return total / sampleCount;
}

// =====================================================
// COUGH TEST
// =====================================================

void performCoughTest() {

  waitForButton("COUGH TEST");

  countdown("COUGH");

  Serial.println();
  Serial.println("========================");
  Serial.println("COUGH TEST");
  Serial.println("========================");

  if (!microphoneReady) {

    showMessage(
      "COUGH ERROR",
      "INMP441 error",
      "Check wiring"
    );

    Serial.println(
      "INMP441 unavailable."
    );

    coughFeature = 0;

    delay(2500);

    return;
  }

  showMessage(
    "COUGH TEST",
    "COUGH NOW!",
    "5 seconds"
  );

  Serial.println("COUGH NOW!");

  long maximumSound = 0;

  long totalSound = 0;

  int validReadings = 0;

  unsigned long startTime =
    millis();

  while (
    millis() - startTime < 5000
  ) {

    long sound =
      readMicrophone();

    if (sound > maximumSound) {

      maximumSound = sound;
    }

    totalSound += sound;

    validReadings++;

    Serial.print("Sound = ");
    Serial.println(sound);

    delay(40);
  }

  long averageSound = 0;

  if (validReadings > 0) {

    averageSound =
      totalSound / validReadings;
  }

  coughFeature =
    maximumSound;

  Serial.println();
  Serial.println("---- COUGH RESULT ----");

  Serial.print("Average sound = ");
  Serial.println(averageSound);

  Serial.print("Maximum sound = ");
  Serial.println(coughFeature);

  char result[22];

  sprintf(
    result,
    "Feature: %ld",
    coughFeature
  );

  showMessage(
    "COUGH COMPLETE",
    result,
    "Press button"
  );

  delay(1500);

  waitForButton("START ANALYSIS");
}

// =====================================================
// RISK CALCULATION
// =====================================================

int calculateRisk() {

  int score = 0;

  // SpO2
  if (spo2Valid) {

    if (spo2Value < 90) {

      score += 35;

    } else if (spo2Value < 94) {

      score += 25;

    } else {

      score += 5;
    }
  }

  // Airflow
  if (airflowFeature > 0) {

    if (airflowFeature < 10000) {

      score += 35;

    } else if (airflowFeature < 50000) {

      score += 20;

    } else {

      score += 5;
    }
  }

  // Cough
  if (coughFeature > 2000) {

    score += 30;

  } else if (coughFeature > 500) {

    score += 20;

  } else if (coughFeature > 0) {

    score += 5;
  }

  if (score > 100) {
    score = 100;
  }

  return score;
}

// =====================================================
// BLUETOOTH FINAL DATA
// =====================================================

void sendBluetoothResults(int riskScore) {

  SerialBT.println();
  SerialBT.println("========================");
  SerialBT.println("COPD SCREENING RESULTS");
  SerialBT.println("========================");

  SerialBT.print("Airflow feature = ");
  SerialBT.println(airflowFeature);

  if (spo2Valid) {

    SerialBT.print("SpO2 = ");
    SerialBT.print(spo2Value);
    SerialBT.println(" %");

  } else {

    SerialBT.println("SpO2 = INVALID");
  }

  if (heartRateValid) {

    SerialBT.print("Heart Rate = ");
    SerialBT.print(heartRateValue);
    SerialBT.println(" BPM");

  } else {

    SerialBT.println("Heart Rate = INVALID");
  }

  SerialBT.print("Cough feature = ");
  SerialBT.println(coughFeature);

  SerialBT.println("------------------------");

  SerialBT.print("Risk Score = ");
  SerialBT.print(riskScore);
  SerialBT.println(" / 100");

  if (riskScore < 35) {

    SerialBT.println("Risk = LOW");

  } else if (riskScore < 65) {

    SerialBT.println("Risk = MODERATE");

  } else {

    SerialBT.println("Risk = HIGH");
    SerialBT.println("REFER FOR SPIROMETRY");
  }

  SerialBT.println("========================");
  SerialBT.println();
}

// =====================================================
// FINAL RESULT
// =====================================================

void showFinalResult() {

  int riskScore =
    calculateRisk();

  Serial.println();
  Serial.println("========================");
  Serial.println("FINAL SENSOR RESULTS");
  Serial.println("========================");

  Serial.print("Airflow feature = ");
  Serial.println(airflowFeature);

  if (spo2Valid) {

    Serial.print("SpO2 = ");
    Serial.print(spo2Value);
    Serial.println(" %");

  } else {

    Serial.println("SpO2 = INVALID");
  }

  if (heartRateValid) {

    Serial.print("Heart Rate = ");
    Serial.print(heartRateValue);
    Serial.println(" BPM");

  } else {

    Serial.println("Heart Rate = INVALID");
  }

  Serial.print("Cough feature = ");
  Serial.println(coughFeature);

  Serial.println("========================");

  Serial.print("FINAL RISK SCORE = ");
  Serial.print(riskScore);
  Serial.println(" / 100");

  if (riskScore < 35) {

    Serial.println("LOW RISK");

  } else if (riskScore < 65) {

    Serial.println("MODERATE RISK");

  } else {

    Serial.println("HIGH RISK");
    Serial.println("REFER FOR SPIROMETRY");
  }

  Serial.println("========================");

  // ---------- BLUETOOTH ----------
  sendBluetoothResults(riskScore);

  // ---------- OLED ----------

  oled.clearBuffer();

  oled.setFont(
    u8g2_font_6x12_tf
  );

  oled.drawStr(
    2,
    12,
    "FINAL RESULT"
  );

  char line2[25];

  sprintf(
    line2,
    "Risk Score: %d/100",
    riskScore
  );

  oled.drawStr(
    2,
    28,
    line2
  );

  char line3[22];

  if (spo2Valid) {

    sprintf(
      line3,
      "SpO2: %d %%",
      spo2Value
    );

  } else {

    sprintf(
      line3,
      "SpO2: INVALID"
    );
  }

  oled.drawStr(
    2,
    43,
    line3
  );

  if (riskScore < 35) {

    oled.drawStr(
      2,
      58,
      "RISK: LOW"
    );

  } else if (riskScore < 65) {

    oled.drawStr(
      2,
      58,
      "RISK: MODERATE"
    );

  } else {

    oled.drawStr(
      2,
      58,
      "RISK: HIGH"
    );
  }

  oled.sendBuffer();
}

// =====================================================
// SETUP
// =====================================================

void setup() {

  Serial.begin(115200);

  delay(1000);

  // ---------- BLUETOOTH ----------

  SerialBT.begin("COPD_Screening");

  Serial.println();
  Serial.println("Bluetooth started.");
  Serial.println("Device name: COPD_Screening");

  Serial.println();
  Serial.println("========================");
  Serial.println("COPD SCREENING SYSTEM");
  Serial.println("========================");

  // ---------- BUTTON ----------

  pinMode(
    BUTTON_PIN,
    INPUT_PULLUP
  );

  // ---------- HX710B ----------

  pinMode(
    HX_OUT,
    INPUT
  );

  pinMode(
    HX_SCK,
    OUTPUT
  );

  digitalWrite(
    HX_SCK,
    LOW
  );

  // ---------- OLED ----------

  oled.begin();

  showMessage(
    "COPD SCREENING",
    "Initializing...",
    "Please wait"
  );

  delay(1500);

  // ---------- MAX30102 ----------

  setupMAX30102();

  // ---------- MICROPHONE ----------

  setupMicrophone();

  // ---------- PRESSURE ----------

  calibratePressure();

  // ---------- READY ----------

  showMessage(
    "SYSTEM READY",
    "Press button",
    "to START"
  );

  Serial.println();
  Serial.println("SYSTEM READY");
  Serial.println("Press button to START.");
  Serial.println("Bluetooth: COPD_Screening");
}

// =====================================================
// MAIN LOOP
// =====================================================

void loop() {

  // ===================================================
  // START
  // ===================================================

  waitForButton(
    "START SCREENING"
  );

  countdown(
    "SCREENING"
  );

  // ===================================================
  // 1. SpO2
  // ===================================================

  performSpO2Test();

  // ===================================================
  // 2. AIRFLOW
  // ===================================================

  performAirflowTest();

  // ===================================================
  // 3. COUGH
  // ===================================================

  performCoughTest();

  // ===================================================
  // ANALYSIS
  // ===================================================

  showMessage(
    "ANALYZING",
    "Sensor results",
    "Please wait"
  );

  Serial.println();
  Serial.println(
    "Analyzing sensor results..."
  );

  delay(3000);

  // ===================================================
  // FINAL RESULT
  // ===================================================

  showFinalResult();

  delay(5000);

  // ===================================================
  // COMPLETE
  // ===================================================

  showMessage(
    "TEST COMPLETE",
    "Press button",
    "for new test"
  );

  Serial.println();
  Serial.println("TEST COMPLETE");
  Serial.println("Press button for new test.");

  while (
    digitalRead(BUTTON_PIN) == HIGH
  ) {
    delay(20);
  }

  while (
    digitalRead(BUTTON_PIN) == LOW
  ) {
    delay(20);
  }

  delay(500);
}

