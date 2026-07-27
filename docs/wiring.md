# Skema Pengkabelan

## Pulse Sensor → Arduino Uno

| Pin Pulse Sensor | Pin Arduino Uno |
|-------------------|-----------------|
| Signal            | A0              |
| VCC (+)           | 5V              |
| GND (-)           | GND             |

## OLED SSD1306 (I2C) → Arduino Uno

| Pin OLED | Pin Arduino Uno |
|----------|-----------------|
| VDD      | 5V              |
| GND      | GND             |
| SCK/SCL  | A5 (SCL)        |
| SDA      | A4 (SDA)        |

## Catatan

- Alamat I2C default OLED SSD1306 pada firmware ini adalah `0x3C`
  (`oled.begin(SSD1306_SWITCHCAPVCC, 0x3C)`); sesuaikan bila modul yang
  digunakan memakai alamat lain (mis. `0x3D`).
- Pulse Sensor sebaiknya dijepit pada ujung jari telunjuk dengan tekanan
  ringan dan tangan bertumpu pada permukaan datar untuk meminimalkan
  artefak gerak (*motion artifact*) selama pengukuran.
