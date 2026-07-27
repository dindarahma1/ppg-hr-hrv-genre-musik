/*
  ppg_hr_hrv_acquisition.ino
  ---------------------------------------------------------------
  Firmware akuisisi sinyal Photoplethysmography (PPG) berbasis
  Arduino Uno, Pulse Sensor, dan OLED Display (SSD1306, I2C).

  Fungsi utama:
  - Membaca sinyal PPG mentah melalui ADC (pin A0)
  - Menerapkan threshold adaptif untuk deteksi puncak sistolik
  - Menghitung Heart Rate (HR) dan estimasi HRV (RMSSD) tiap 60 detik
  - Menampilkan grafik gelombang sinyal serta nilai HR/HRV pada OLED
  - Mengirim data mentah (waktu, amplitudo) melalui Serial untuk
    disimpan dan diolah lebih lanjut (mis. di MATLAB)

  Bagian dari penelitian:
  "Perbandingan Pengaruh Genre Musik Berbeda terhadap Respons
  Fisiologis yang Berkaitan dengan Stres Menggunakan PPG"
  Dinda Rahma Annisah - Program Studi Teknik Komputer,
  Fakultas Ilmu Komputer, Universitas Brawijaya
  ---------------------------------------------------------------
*/

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <math.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define sensor A0

Adafruit_SSD1306 oled(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire);

// Variabel Grafik
int x = 0;
int lastX = 0, lastY = 60;

// Variabel Deteksi Detak
int liveCount = 0;        // Mencatat detak secara real-time
int finalBpm = 0;         // Hasil akhir BPM setelah 60 detik
unsigned long lastMillis = 0;
unsigned long lastBeatTime = 0;
bool pulseDetected = false;
bool firstMinutePassed = false;
int minuteCounter = 0;

// Variabel HRV (RMSSD)
long ibi = 0;
long lastIbi = 0;
long sumSquaredDiff = 0;
int beatCountForHRV = 0;
float finalRmssd = 0;

// Variabel Auto-Threshold
int signalMax = 0;
int signalMin = 1024;
int threshold = 520;
unsigned long lastThresholdUpdate = 0;
const unsigned long thresholdWindow = 2000; // 2 detik

void setup() {
  Serial.begin(115200);

  if (!oled.begin(SSD1306_SWITCHCAPVCC, 0x3C)) for (;;);
  oled.clearDisplay();
  lastMillis = millis();
  lastBeatTime = millis();
  Serial.println("Time,Signal");
}

void loop() {
  int Svalue = analogRead(sensor);

  // Serial Plotter / logging untuk penyimpanan data (.txt)
  Serial.print(millis()); Serial.print(",");
  Serial.println(Svalue);

  // Adaptif Threshold
  if (Svalue > signalMax) signalMax = Svalue;
  if (Svalue < signalMin) signalMin = Svalue;

  if (millis() - lastThresholdUpdate >= thresholdWindow) {
    threshold = (signalMax + signalMin) / 2;
    signalMax = 0;
    signalMin = 1024;
    lastThresholdUpdate = millis();
  }

  // Visualisasi Grafik (Area Bawah)
  int value = map(Svalue, 0, 1023, 0, 30);
  int y = 60 - value;
  if (x > 128) {
    x = 0;
    lastX = 0;
    oled.fillRect(0, 32, 128, 32, BLACK);
  }
  oled.drawLine(lastX, lastY, x, y, WHITE);
  lastX = x; lastY = y; x++;

  // Logika Deteksi Detak Real-Time & HRV
  if (Svalue > (threshold + 25) && !pulseDetected) {
    unsigned long currentBeatTime = millis();
    ibi = currentBeatTime - lastBeatTime;

    if (ibi > 400 && ibi < 1200) {
      liveCount++; // Mencatat setiap detak yang terjadi

      if (lastIbi > 0) {
        long diff = abs(ibi - lastIbi);
        if (diff < 300) { // Filter noise untuk HRV
          sumSquaredDiff += (diff * diff);
          beatCountForHRV++;
        }
      }
      lastIbi = ibi;
    }
    lastBeatTime = currentBeatTime;
    pulseDetected = true;
  }
  if (Svalue < threshold) {
    pulseDetected = false;
  }

  // Tampilan OLED (Area Atas)
  oled.fillRect(0, 0, 128, 30, BLACK); // Refresh area teks saja
  oled.setTextColor(WHITE);
  oled.setTextSize(1);

  if (!firstMinutePassed) {
    // TAMPILAN SAAT SENSING PERTAMA
    oled.setCursor(0, 0);
    oled.print("Sensing: "); oled.print((millis() - lastMillis) / 1000); oled.print("s");

    oled.setCursor(0, 15);
    oled.print("Detak: "); oled.print(liveCount);
  } else {
    // TAMPILAN SETELAH 1 MENIT (BPM & HRV FINAL)
    oled.setCursor(0, 0);
    oled.print("HR: "); oled.print(finalBpm); oled.print(" bpm");
    oled.print(" Detak: "); oled.print(liveCount); // Live count menit berjalan
    oled.setCursor(0, 15);
    oled.print("HRV: "); oled.print(finalRmssd, 1); oled.print(" ms");
  }

  // Update Data Setiap 60 Detik
  if (millis() - lastMillis >= 60000) {
    minuteCounter++;
    finalBpm = liveCount; // Pindahkan hitungan live ke final

    if (beatCountForHRV > 0) {
      finalRmssd = sqrt(sumSquaredDiff / beatCountForHRV);
    } else {
      finalRmssd = 0;
    }

    // Reset untuk siklus menit berikutnya
    liveCount = 0;
    sumSquaredDiff = 0;
    beatCountForHRV = 0;
    lastIbi = 0;
    lastMillis = millis();
    firstMinutePassed = true;
  }

  oled.display();
  delay(10);
}
