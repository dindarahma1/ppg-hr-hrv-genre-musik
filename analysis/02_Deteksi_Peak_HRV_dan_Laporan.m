%% ============================================================
%  SKRIP 2: DETEKSI PEAK, HITUNG HR & HRV, LAPORAN FINAL
%  (gabungan skrip deteksi peak + visualisasi/tabel laporan)
%
%  Prasyarat: jalankan 01_Pemrosesan_dan_Filtering_PPG.m lebih dulu
%             (menghasilkan ppg_workspace.mat)
%
%  Tahapan:
%   1. Deteksi peak sistolik (findpeaks)
%   2. Hitung interval RR & filter RR yang tidak fisiologis
%   3. Hitung Heart Rate (HR)
%   4. Hitung HRV domain waktu: SDNN, RMSSD, pNN50, CV
%   5. Figure A - Pipeline 4 panel (raw -> preprocessed -> filtered -> peak/RR)
%   6. Figure B - Spektrum FFT sebelum vs sesudah filter
%   7. Figure C - Distribusi HR instantaneous
%   8. Tabel ringkasan hasil (Command Window + file .txt)
% ============================================================

clear; clc; close all;
load('ppg_workspace.mat');

%% --- 1. DETEKSI PEAK DENGAN findpeaks() ---
% MinPeakHeight     : minimal 0.3 di atas rata-rata (data sudah Z-score)
% MinPeakDistance   : minimal 0.4 detik antar puncak (setara maks 150 bpm)
% MinPeakProminence : menjamin puncak cukup menonjol
min_dist_s   = 0.4;
min_dist_smp = round(min_dist_s * fs);

[peak_vals, peak_idx] = findpeaks(ppg_filtered_norm, ...
    'MinPeakHeight',     0.3, ...
    'MinPeakDistance',   min_dist_smp, ...
    'MinPeakProminence', 0.5);

peak_times = time_s(peak_idx);

fprintf('=== 1. DETEKSI PEAK ===\n');
fprintf('Jumlah peak terdeteksi   : %d\n', length(peak_idx));
fprintf('Rata-rata amplitudo peak : %.4f\n', mean(peak_vals));

%% --- 2. INTERVAL RR ---
RR_s        = diff(peak_times);
RR_ms       = RR_s * 1000;
valid_RR    = (RR_ms >= 200) & (RR_ms <= 2000);   % fisiologis: 30-300 bpm
RR_ms_valid = RR_ms(valid_RR);

fprintf('\n=== 2. INTERVAL RR ===\n');
fprintf('Jumlah RR total          : %d\n', length(RR_ms));
fprintf('Jumlah RR valid          : %d\n', length(RR_ms_valid));
fprintf('RR rata-rata             : %.2f ms\n', mean(RR_ms_valid));
fprintf('RR min / max             : %.2f / %.2f ms\n', min(RR_ms_valid), max(RR_ms_valid));

%% --- 3. HEART RATE (HR) ---
HR_mean_bpm = 60000 / mean(RR_ms_valid);
HR_inst_bpm = 60000 ./ RR_ms_valid;

fprintf('\n=== 3. HEART RATE (HR) ===\n');
fprintf('HR rata-rata : %.2f bpm\n', HR_mean_bpm);
fprintf('HR min / max : %.2f / %.2f bpm\n', min(HR_inst_bpm), max(HR_inst_bpm));
fprintf('HR std. dev  : %.2f bpm\n', std(HR_inst_bpm));

%% --- 4. HRV DOMAIN WAKTU ---
SDNN             = std(RR_ms_valid);                       % variabilitas keseluruhan
successive_diff  = diff(RR_ms_valid);
RMSSD            = sqrt(mean(successive_diff.^2));         % aktivitas parasimpatis
count_NN50       = sum(abs(successive_diff) > 50);
pNN50            = (count_NN50 / length(successive_diff)) * 100;
CV               = (SDNN / mean(RR_ms_valid)) * 100;

fprintf('\n=== 4. HRV DOMAIN WAKTU ===\n');
fprintf('SDNN  : %.2f ms\n', SDNN);
fprintf('RMSSD : %.2f ms\n', RMSSD);
fprintf('pNN50 : %.2f %%\n', pNN50);
fprintf('CV    : %.2f %%\n', CV);

fprintf('\n--- Interpretasi Awal ---\n');
if SDNN > 50
    fprintf('SDNN  > 50 ms  -> variabilitas jantung NORMAL/BAIK\n');
elseif SDNN > 20
    fprintf('SDNN  20-50 ms -> variabilitas jantung CUKUP\n');
else
    fprintf('SDNN  < 20 ms  -> variabilitas jantung RENDAH (indikasi stres)\n');
end
if RMSSD > 20
    fprintf('RMSSD > 20 ms  -> aktivitas parasimpatis AKTIF (relaksasi)\n');
else
    fprintf('RMSSD < 20 ms  -> aktivitas parasimpatis RENDAH (indikasi stres)\n');
end

% waktu RR untuk plotting (dari puncak ke-2 dst, hanya yang valid)
peak_times_mid = peak_times(2:end);
peak_valid_t   = peak_times_mid(valid_RR);

%% --- 5. FIGURE A: PIPELINE LENGKAP (4 PANEL) - untuk BAB III/IV ---
fig1 = figure('Name','Pipeline Analisis PPG','Units','centimeters','Position',[1 1 22 22]);

ax1 = subplot(4,1,1);
plot(time_s, ppg_raw, 'Color',[0.5 0.5 0.5],'LineWidth',0.8); hold on;
plot(time_s, baseline + mean(ppg_raw), 'r--', 'LineWidth', 1.2);
ylabel('ADC'); title('(a) Sinyal PPG Mentah (Raw)','FontWeight','bold');
legend('Raw','Baseline','Location','northeast','FontSize',7); grid on; box on;

ax2 = subplot(4,1,2);
plot(time_s, ppg_detrend, 'Color',[0.2 0.6 0.3],'LineWidth',0.9); yline(0,'k--');
ylabel('Amplitudo'); title('(b) Setelah Detrending & Normalisasi','FontWeight','bold'); grid on; box on;

ax3 = subplot(4,1,3);
plot(time_s, ppg_filtered_norm, 'Color',[0.8 0.3 0.1],'LineWidth',1.0); yline(0,'k--');
ylabel('Z-score'); title('(c) Setelah Bandpass Filter (0.5-5 Hz)','FontWeight','bold'); grid on; box on;

ax4 = subplot(4,1,4);
yyaxis left;
plot(time_s, ppg_filtered_norm, 'Color',[0.2 0.4 0.8],'LineWidth',0.9); hold on;
plot(peak_times, peak_vals, 'rv', 'MarkerSize', 5, 'MarkerFaceColor','r');
ylabel('Z-score');
yyaxis right;
plot(peak_valid_t, RR_ms_valid, 's--', 'Color',[0.5 0 0.5], ...
     'MarkerSize', 3, 'MarkerFaceColor',[0.5 0 0.5], 'LineWidth', 0.8);
ylabel('RR (ms)'); xlabel('Waktu (detik)');
title(sprintf('(d) Deteksi Peak + Tachogram | HR = %.1f bpm | SDNN = %.1f ms | RMSSD = %.1f ms', ...
              HR_mean_bpm, SDNN, RMSSD), 'FontWeight','bold');
legend('PPG Filtered','Peak Sistolik','RR Interval','Location','northeast','FontSize',7);
grid on; box on;

linkaxes([ax1 ax2 ax3 ax4],'x');
sgtitle({'Pipeline Analisis Sinyal PPG (Photoplethysmography)', ...
         'Arduino Uno + Pulse Sensor -> Ekstraksi HR & HRV'}, 'FontWeight','bold');

exportgraphics(fig1, 'Gambar_05_Pipeline_Peak_RR.pdf', 'ContentType', 'vector');
exportgraphics(fig1, 'Gambar_05_Pipeline_Peak_RR.png', 'Resolution', 300);

%% --- 6. FIGURE B: SPEKTRUM FFT SEBELUM VS SESUDAH FILTER ---
fig2 = figure('Name','Spektrum FFT','Units','centimeters','Position',[25 1 18 10]);
N2  = length(ppg_detrend);
Y_b = fft(ppg_detrend, N2);  Pb = abs(Y_b/N2); Pb = Pb(1:floor(N2/2)+1); Pb(2:end-1)=2*Pb(2:end-1);
Y_a = fft(ppg_filtered, N2); Pa = abs(Y_a/N2); Pa = Pa(1:floor(N2/2)+1); Pa(2:end-1)=2*Pa(2:end-1);
f2  = fs * (0:floor(N2/2)) / N2;
idx = f2 <= 12;

plot(f2(idx), 20*log10(Pb(idx)+eps), 'Color',[0.6 0.6 0.6],'LineWidth',1.0); hold on;
plot(f2(idx), 20*log10(Pa(idx)+eps), 'Color',[0.8 0.2 0.1],'LineWidth',1.3);
xline(f_low,  'g--', 'LineWidth',1.0, 'Label','0.5 Hz');
xline(f_high, 'b--', 'LineWidth',1.0, 'Label','5.0 Hz');
xline(f_dominan, 'm-', 'LineWidth',1.5, ...
      'Label', sprintf('%.2f Hz (%.0f bpm)', f_dominan, HR_dari_FFT));
xlabel('Frekuensi (Hz)'); ylabel('Amplitudo (dB)');
title({'Spektrum Frekuensi Sinyal PPG', ...
       sprintf('SNR sebelum = %.2f dB | SNR sesudah = %.2f dB | Frekuensi dominan = %.2f Hz (~ %.0f bpm)', ...
               SNR_dB_sebelum, SNR_dB_sesudah, f_dominan, HR_dari_FFT)}, 'FontWeight','bold');
legend('Sebelum filter','Setelah bandpass filter','Location','northeast','FontSize',9);
grid on; box on; xlim([0 12]);

exportgraphics(fig2, 'Gambar_06_Spektrum_FFT.pdf', 'ContentType', 'vector');
exportgraphics(fig2, 'Gambar_06_Spektrum_FFT.png', 'Resolution', 300);

%% --- 7. FIGURE C: DISTRIBUSI HR INSTANTANEOUS ---
fig3 = figure('Name','Distribusi Heart Rate','Units','centimeters','Position',[2 2 18 10]);
histogram(HR_inst_bpm, 15, 'FaceColor',[0.2 0.6 0.4], 'EdgeColor','white');
xline(HR_mean_bpm, 'r-', sprintf('HR Mean = %.1f bpm', HR_mean_bpm), 'LineWidth', 1.5);
xlabel('Heart Rate (bpm)'); ylabel('Frekuensi (jumlah detak)');
title('Distribusi Heart Rate Instantaneous', 'FontWeight','bold'); grid on;

exportgraphics(fig3, 'Gambar_07_Distribusi_HR.png', 'Resolution', 300);

fprintf('\n[FIGURE] 3 gambar laporan disimpan (pipeline, spektrum FFT, distribusi HR).\n');

%% --- 8. TABEL RINGKASAN HASIL ---
fprintf('\n');
fprintf('======================= TABEL HASIL ANALISIS SINYAL PPG =======================\n');
fprintf('File sumber              : %s\n', nama_file);
fprintf('Jumlah sampel            : %d\n', length(time_s));
fprintf('Durasi rekaman           : %.2f detik\n', time_s(end)-time_s(1));
fprintf('Sampling rate (fs)       : %.2f Hz\n', fs);
fprintf('SNR sebelum / sesudah    : %.2f dB / %.2f dB\n', SNR_dB_sebelum, SNR_dB_sesudah);
fprintf('---------------------------------------------------------------------------\n');
fprintf('HR rata-rata / min / max : %.2f / %.2f / %.2f bpm\n', HR_mean_bpm, min(HR_inst_bpm), max(HR_inst_bpm));
fprintf('HR std. deviasi          : %.2f bpm\n', std(HR_inst_bpm));
fprintf('---------------------------------------------------------------------------\n');
fprintf('Jumlah RR interval valid : %d\n', length(RR_ms_valid));
fprintf('Mean RR                  : %.2f ms\n', mean(RR_ms_valid));
fprintf('SDNN                     : %.2f ms\n', SDNN);
fprintf('RMSSD                    : %.2f ms\n', RMSSD);
fprintf('pNN50                    : %.2f %%\n', pNN50);
fprintf('CV                       : %.2f %%\n', CV);
fprintf('---------------------------------------------------------------------------\n');
fprintf('Filter                   : Butterworth Bandpass Orde %d, %.1f-%.1f Hz, filtfilt\n', ...
        orde_filter, f_low, f_high);
fprintf('=============================================================================\n');

fid = fopen('Tabel_Hasil_HR_HRV.txt', 'w');
fprintf(fid, 'TABEL HASIL ANALISIS SINYAL PPG\n');
fprintf(fid, 'File sumber: %s\n\n', nama_file);
fprintf(fid, 'Parameter Sinyal:\n');
fprintf(fid, '  Sampling rate       : %.2f Hz\n', fs);
fprintf(fid, '  Durasi              : %.2f detik\n', time_s(end)-time_s(1));
fprintf(fid, '  SNR sebelum filter  : %.2f dB\n', SNR_dB_sebelum);
fprintf(fid, '  SNR sesudah filter  : %.2f dB\n\n', SNR_dB_sesudah);
fprintf(fid, 'Heart Rate (HR):\n');
fprintf(fid, '  HR Mean : %.2f bpm\n', HR_mean_bpm);
fprintf(fid, '  HR Min  : %.2f bpm\n', min(HR_inst_bpm));
fprintf(fid, '  HR Max  : %.2f bpm\n', max(HR_inst_bpm));
fprintf(fid, '  HR Std  : %.2f bpm\n\n', std(HR_inst_bpm));
fprintf(fid, 'Heart Rate Variability (HRV):\n');
fprintf(fid, '  Mean RR : %.2f ms\n', mean(RR_ms_valid));
fprintf(fid, '  SDNN    : %.2f ms\n', SDNN);
fprintf(fid, '  RMSSD   : %.2f ms\n', RMSSD);
fprintf(fid, '  pNN50   : %.2f %%\n', pNN50);
fprintf(fid, '  CV      : %.2f %%\n', CV);
fclose(fid);

%% --- 9. SIMPAN SEMUA HASIL AKHIR ---
save('ppg_workspace.mat', 'peak_idx','peak_times','peak_vals','RR_ms','RR_ms_valid', ...
     'valid_RR','HR_mean_bpm','HR_inst_bpm','SDNN','RMSSD','pNN50','CV', '-append');

fprintf('\n[SKRIP 2 SELESAI] Semua output siap untuk laporan skripsi.\n');
fprintf('File yang dihasilkan:\n');
fprintf('  - Gambar_05_Pipeline_Peak_RR.pdf/png\n');
fprintf('  - Gambar_06_Spektrum_FFT.pdf/png\n');
fprintf('  - Gambar_07_Distribusi_HR.png\n');
fprintf('  - Tabel_Hasil_HR_HRV.txt\n');
