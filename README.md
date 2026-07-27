# Sistem Akuisisi PPG untuk Analisis Pengaruh Genre Musik terhadap Respons Fisiologis

Repository ini berisi kode program (firmware) untuk sistem akuisisi sinyal
**Photoplethysmography (PPG)** berbasis **Arduino Uno**, **Pulse Sensor**, dan
**OLED Display (SSD1306)**. Sistem ini digunakan untuk mengukur **Heart Rate (HR)**
dan estimasi **Heart Rate Variability (HRV)** berbasis metode RMSSD secara
*real-time*

## Struktur Repository

```
├── firmware/
│   └── ppg_hr_hrv_acquisition.ino   # Firmware utama Arduino Uno
├── analysis/
│   ├── 01_Pemrosesan_dan_Filtering_PPG.m       # Tahap 1: import, resample, filter Butterworth
│   └── 02_Deteksi_Peak_HRV_dan_Laporan.m       # Tahap 2: deteksi peak, HR, HRV, laporan
├── docs/
│   └── wiring.md                    # Skema pengkabelan komponen
├── LICENSE
└── README.md
```

## Perangkat Keras

| Komponen         | Keterangan                                   |
|-------------------|-----------------------------------------------|
| Arduino Uno       | Unit pemrosesan sinyal (ATmega328P)           |
| Pulse Sensor      | Sensor PPG, terhubung ke pin analog **A0**    |
| OLED SSD1306 (I2C)| Layar 128x64, menampilkan grafik & nilai HR/HRV|
| Breadboard + kabel jumper | Rangkaian prototipe                  |

Detail pengkabelan lengkap ada di [`docs/wiring.md`](docs/wiring.md).

## Kebutuhan Pustaka (Library) Arduino

Install melalui **Arduino IDE → Tools → Manage Libraries**:

- `Adafruit GFX Library`
- `Adafruit SSD1306`
- (Wire dan math sudah termasuk dalam Arduino core)

## Cara Penggunaan

1. Rangkai perangkat keras sesuai [`docs/wiring.md`](docs/wiring.md).
2. Buka `firmware/ppg_hr_hrv_acquisition.ino` di Arduino IDE.
3. Pilih board **Arduino Uno** dan port serial yang sesuai.
4. Upload program ke Arduino.
5. Buka **Serial Monitor/Plotter** (baud rate `115200`) untuk memantau data
   mentah (`Time,Signal`), atau lihat langsung grafik dan nilai HR/HRV pada
   layar OLED.
6. Letakkan ujung jari pada Pulse Sensor. Dalam 60 detik pertama, layar
   menampilkan status `Sensing...` beserta jumlah detak yang tercatat.
   Setelah itu, nilai **HR (bpm)** dan **HRV/RMSSD (ms)** ditampilkan dan
   diperbarui setiap 60 detik.

## Cara Kerja Singkat

- Sinyal PPG mentah dibaca dari pin analog A0 (ADC 10-bit, VREF 5V).
- **Threshold adaptif** dihitung ulang setiap 2 detik berdasarkan nilai
  maksimum dan minimum sinyal pada jendela waktu tersebut, untuk mengikuti
  perubahan amplitudo sinyal antar sesi/responden.
- **Deteksi puncak sistolik** dilakukan saat sinyal melewati
  `threshold + 25`, dengan validasi interval antar-detak (IBI) pada rentang
  400–1200 ms untuk menyaring artefak.
- **HRV (RMSSD)** dihitung dari akar rata-rata kuadrat selisih antar-IBI
  yang valid (selisih < 300 ms untuk menyaring noise).
- Nilai HR dan HRV final diperbarui tiap 60 detik dan ditampilkan pada OLED.

## Pengolahan Sinyal Lanjutan (MATLAB)

Data mentah (`Time,Signal`) yang dikirim melalui Serial disimpan sebagai
file `.txt` per responden/kondisi (mis. `S18Hiphop.txt`), kemudian diproses
melalui dua skrip MATLAB pada folder `analysis/`:

1. **`01_Pemrosesan_dan_Filtering_PPG.m`**
   Import data mentah → resample ke fs tetap 20 Hz → detrending &
   normalisasi Z-score → analisis noise (FFT & SNR sebelum filter) →
   filtering Bandpass Butterworth orde 4 (0,5–5 Hz, `filtfilt`) → SNR
   sesudah filter → simpan workspace (`ppg_workspace.mat`).

2. **`02_Deteksi_Peak_HRV_dan_Laporan.m`**
   Memuat `ppg_workspace.mat` dari skrip 1 → deteksi puncak sistolik
   (`findpeaks`) → hitung interval RR (dengan validasi rentang fisiologis
   200–2000 ms) → hitung Heart Rate (HR) → hitung HRV domain waktu (SDNN,
   RMSSD, pNN50, CV) → menghasilkan figure pipeline, spektrum FFT, dan
   distribusi HR → menyimpan tabel ringkasan hasil (`Tabel_Hasil_HR_HRV.txt`).

**Cara menjalankan:**
1. Letakkan file data mentah (`.txt`) pada folder kerja MATLAB yang sama.
2. Ubah variabel `nama_file` pada `01_Pemrosesan_dan_Filtering_PPG.m` sesuai
   file yang ingin diproses, lalu jalankan skrip tersebut.
3. Jalankan `02_Deteksi_Peak_HRV_dan_Laporan.m` untuk mendapatkan nilai HR,
   HRV (SDNN, RMSSD, pNN50, CV), serta figure dan tabel hasil analisis.

## Lisensi

Kode program pada repository ini dirilis di bawah lisensi MIT — lihat
[`LICENSE`](LICENSE) untuk detail.
