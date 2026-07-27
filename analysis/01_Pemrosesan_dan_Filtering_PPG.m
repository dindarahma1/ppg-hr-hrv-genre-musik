clear; clc; close all;

%% --- PENGATURAN ---
nama_file   = 'S18Hiphop.txt';   % ganti sesuai file data (responden/kondisi)
fs          = 20;                % sampling rate tetap (Hz)
f_low       = 0.5;               % batas bawah pita PPG (Hz)
f_high      = 5.0;               % batas atas pita PPG (Hz)
orde_filter = 4;                 % orde filter Butterworth

%% --- 1. IMPORT DATA MENTAH ---
data          = readtable(nama_file);
time_ms_asli  = data.Time;      % waktu asli (ms), interval tidak seragam
ppg_raw_asli  = data.Signal;    % nilai ADC (0-1023 Arduino)
time_s_asli   = time_ms_asli / 1000;

dt_ms_terukur = mean(diff(time_ms_asli));
fs_terukur    = 1000 / dt_ms_terukur;   % untuk validasi laporan

fprintf('=== 1. IMPORT DATA ===\n');
fprintf('File               : %s\n', nama_file);
fprintf('Jumlah sampel asli : %d\n', length(time_s_asli));
fprintf('Durasi sinyal      : %.2f detik\n', time_s_asli(end) - time_s_asli(1));
fprintf('fs terukur (asli)  : %.2f Hz (interval rata-rata %.2f ms)\n', fs_terukur, dt_ms_terukur);
fprintf('fs tetap dipakai   : %.2f Hz\n', fs);

%% --- 2. RESAMPLE KE fs TETAP ---
% Data Arduino tidak berjarak waktu tetap, sehingga diseragamkan dahulu
% pada fs = 20 Hz sebelum FFT/filter (keduanya asumsikan sampling seragam).
time_s  = (time_s_asli(1) : 1/fs : time_s_asli(end))';
ppg_raw = interp1(time_s_asli, ppg_raw_asli, time_s, 'linear');
time_ms = time_s * 1000;
dt_ms   = 1000 / fs;

fprintf('\n=== 2. RESAMPLE ===\n');
fprintf('Jumlah sampel setelah resample : %d\n', length(time_s));

figure('Name','Sinyal PPG Mentah','Units','centimeters','Position',[2 2 18 8]);
plot(time_s, ppg_raw, 'Color', [0.2 0.4 0.8], 'LineWidth', 1.0);
xlabel('Waktu (detik)'); ylabel('Amplitudo (ADC)');
title('Sinyal PPG Mentah Setelah Resample ke fs = 20 Hz', 'FontWeight','bold');
xlim([time_s(1) time_s(end)]); grid on; box on;
exportgraphics(gcf, 'Gambar_01_Sinyal_Raw.png', 'Resolution', 300);

%% --- 3. DETRENDING + NORMALISASI Z-SCORE ---
tren        = polyfit(time_s, ppg_raw, 3);
baseline    = polyval(tren, time_s);
ppg_detrend = ppg_raw - baseline;
ppg_norm    = (ppg_detrend - mean(ppg_detrend)) / std(ppg_detrend);

fprintf('\n=== 3. PRA-PEMROSESAN ===\n');
fprintf('Raw       -> Mean: %.2f | Std: %.2f\n', mean(ppg_raw), std(ppg_raw));
fprintf('Detrend   -> Mean: %.4f | Std: %.2f\n', mean(ppg_detrend), std(ppg_detrend));
fprintf('Normalize -> Mean: %.4f | Std: %.4f\n', mean(ppg_norm), std(ppg_norm));

figure('Name','Pre-processing PPG','Units','centimeters','Position',[2 2 20 16]);
ax1 = subplot(3,1,1);
plot(time_s, ppg_raw, 'Color',[0.5 0.5 0.5],'LineWidth',0.8); hold on;
plot(time_s, baseline, 'r--', 'LineWidth', 1.5);
legend('Sinyal Mentah','Baseline/Tren','Location','northeast','FontSize',8);
ylabel('Amplitudo (ADC)'); title('(a) Sinyal dan Estimasi Baseline','FontWeight','bold'); grid on;
ax2 = subplot(3,1,2);
plot(time_s, ppg_detrend, 'Color',[0.2 0.6 0.4],'LineWidth',0.9); yline(0,'k--');
ylabel('Amplitudo'); title('(b) Setelah Detrending','FontWeight','bold'); grid on;
ax3 = subplot(3,1,3);
plot(time_s, ppg_norm, 'Color',[0.8 0.3 0.1],'LineWidth',0.9); yline(0,'k--');
xlabel('Waktu (detik)'); ylabel('Amplitudo (Z-score)');
title('(c) Setelah Normalisasi Z-score','FontWeight','bold'); grid on;
linkaxes([ax1 ax2 ax3],'x');
sgtitle('Tahapan Pra-pemrosesan Sinyal PPG','FontWeight','bold');
exportgraphics(gcf, 'Gambar_02_Preprocessing.png', 'Resolution', 300);

%% --- 4. ANALISIS NOISE: FFT & SNR (SEBELUM FILTER) ---
N  = length(ppg_detrend);
Y  = fft(ppg_detrend, N);
P2 = abs(Y/N);
P1 = P2(1:floor(N/2)+1);
P1(2:end-1) = 2*P1(2:end-1);
f  = fs * (0:floor(N/2)) / N;
P1_dB = 20*log10(P1 + eps);

idx_signal = (f >= f_low) & (f <= f_high);
idx_noise  = (f < f_low) | (f > f_high);

power_signal   = sum(P1(idx_signal).^2);
power_noise    = sum(P1(idx_noise).^2);
SNR_dB_sebelum = 10*log10(power_signal / power_noise);

[~, idx_peak] = max(P1(idx_signal));
f_dominan   = f(idx_signal); f_dominan = f_dominan(idx_peak);
HR_dari_FFT = f_dominan * 60;

fprintf('\n=== 4. ANALISIS NOISE (SEBELUM FILTER) ===\n');
fprintf('Frekuensi dominan : %.3f Hz (%.1f BPM)\n', f_dominan, HR_dari_FFT);
fprintf('SNR (sebelum filter) : %.2f dB\n', SNR_dB_sebelum);
if SNR_dB_sebelum >= 20
    fprintf('Kualitas sinyal : BAIK (>= 20 dB)\n');
elseif SNR_dB_sebelum >= 10
    fprintf('Kualitas sinyal : CUKUP (10-20 dB)\n');
else
    fprintf('Kualitas sinyal : KURANG (< 10 dB) - filtering diperlukan\n');
end

figure('Name','Analisis Noise FFT','Units','centimeters','Position',[2 2 20 14]);
ax1 = subplot(2,1,1);
fill([f_low f_high f_high f_low], [min(P1_dB)-5 min(P1_dB)-5 max(P1_dB)+5 max(P1_dB)+5], ...
     [0.8 1 0.8], 'EdgeColor','none','FaceAlpha',0.4); hold on;
plot(f, P1_dB, 'Color',[0.15 0.15 0.6],'LineWidth',1.2);
xline(f_low,'g--','Label',sprintf('%.1f Hz',f_low));
xline(f_high,'r--','Label',sprintf('%.1f Hz',f_high));
xline(f_dominan,'m-','LineWidth',1.5, ...
      'Label',sprintf('f dom=%.2f Hz (%.0f BPM)', f_dominan, HR_dari_FFT));
xlabel('Frekuensi (Hz)'); ylabel('Amplitudo (dB)');
title('(a) Spektrum Frekuensi Sinyal PPG (FFT)','FontWeight','bold');
xlim([0, min(fs/2,20)]); grid on;
ax2 = subplot(2,1,2);
idx_zoom = f <= 6;
bar(f(idx_zoom & idx_signal), P1(idx_zoom & idx_signal), 'FaceColor',[0.2 0.7 0.3],'EdgeColor','none'); hold on;
bar(f(idx_zoom & idx_noise), P1(idx_zoom & idx_noise), 'FaceColor',[0.85 0.2 0.2],'EdgeColor','none');
xline(f_dominan,'m-','LineWidth',1.5);
xlabel('Frekuensi (Hz)'); ylabel('Amplitudo');
title(sprintf('(b) Detail 0-6 Hz | SNR = %.2f dB | HR ~ %.0f BPM', SNR_dB_sebelum, HR_dari_FFT),'FontWeight','bold');
xlim([0 6]); grid on;
sgtitle('Analisis Noise Sinyal PPG (Sebelum Filter)','FontWeight','bold');
exportgraphics(gcf, 'Gambar_03_Analisis_Noise.png', 'Resolution', 300);

%% --- 5. FILTERING: BANDPASS BUTTERWORTH ORDE 4 (0.5-5 Hz) ---
f_nyq  = fs / 2;
Wn     = [f_low, f_high] / f_nyq;
[b, a] = butter(orde_filter, Wn, 'bandpass');

fprintf('\n=== 5. DESAIN FILTER ===\n');
fprintf('Jenis filter       : Butterworth Bandpass\n');
fprintf('Orde filter        : %d\n', orde_filter);
fprintf('Rentang frekuensi  : %.1f - %.1f Hz\n', f_low, f_high);
fprintf('Sampling rate (fs) : %.2f Hz\n', fs);

ppg_filtered      = filtfilt(b, a, ppg_detrend);   % zero-phase filtering
ppg_filtered_norm = (ppg_filtered - mean(ppg_filtered)) / std(ppg_filtered);

figure('Name','Hasil Filtering PPG','Units','centimeters','Position',[2 2 20 18]);
ax1 = subplot(3,1,1);
plot(time_s, ppg_detrend, 'Color',[0.6 0.6 0.6],'LineWidth',0.8); hold on;
plot(time_s, ppg_filtered, 'Color',[0.8 0.2 0.1],'LineWidth',1.3);
legend('Sebelum filter (detrended)','Setelah filter (Butterworth 0.5-5 Hz)','Location','northeast','FontSize',8);
ylabel('Amplitudo'); title('(a) Sinyal Sebelum dan Sesudah Filter','FontWeight','bold'); grid on;
ax2 = subplot(3,1,2);
plot(time_s, ppg_filtered_norm, 'Color',[0.1 0.5 0.8],'LineWidth',1.2); yline(0,'k--');
ylabel('Amplitudo (Z-score)'); title('(b) Sinyal PPG Bersih (Filtered & Normalized)','FontWeight','bold'); grid on;
ax3 = subplot(3,1,3);
Y_bef = fft(ppg_detrend, N);  P_bef = abs(Y_bef/N); P_bef = P_bef(1:floor(N/2)+1); P_bef(2:end-1)=2*P_bef(2:end-1);
Y_aft = fft(ppg_filtered, N); P_aft = abs(Y_aft/N); P_aft = P_aft(1:floor(N/2)+1); P_aft(2:end-1)=2*P_aft(2:end-1);
idx_plt = f <= 15;
plot(f(idx_plt), 20*log10(P_bef(idx_plt)+eps), 'Color',[0.6 0.6 0.6],'LineWidth',0.9); hold on;
plot(f(idx_plt), 20*log10(P_aft(idx_plt)+eps), 'Color',[0.8 0.2 0.1],'LineWidth',1.3);
xline(f_low,'g--'); xline(f_high,'b--');
xlabel('Frekuensi (Hz)'); ylabel('Amplitudo (dB)');
title('(c) Spektrum Sebelum vs Sesudah Filter','FontWeight','bold');
legend('Sebelum filter','Setelah filter','Low cut','High cut','Location','northeast','FontSize',8);
grid on;
linkaxes([ax1 ax2],'x');
sgtitle('Hasil Bandpass Filtering (Butterworth Orde 4)','FontWeight','bold');
exportgraphics(gcf, 'Gambar_04_Filtering.png', 'Resolution', 300);

figure('Name','Respons Filter Butterworth','Units','centimeters','Position',[24 2 14 8]);
freqz(b, a, 2048, fs);
title('Respons Frekuensi Filter Butterworth Bandpass (0.5-5 Hz)','FontWeight','bold');
exportgraphics(gcf, 'Gambar_04b_Respons_Filter.png', 'Resolution', 300);

%% --- 6. SNR SESUDAH FILTER (PEMBANDING EFEKTIVITAS FILTER) ---
power_signal_f = sum(P_aft(idx_signal).^2);
power_noise_f  = sum(P_aft(idx_noise).^2);
SNR_dB_sesudah = 10*log10(power_signal_f / power_noise_f);

fprintf('\n=== 6. PERBANDINGAN SNR SEBELUM VS SESUDAH FILTER ===\n');
fprintf('SNR sebelum filter : %.2f dB\n', SNR_dB_sebelum);
fprintf('SNR sesudah filter : %.2f dB\n', SNR_dB_sesudah);
if SNR_dB_sesudah > SNR_dB_sebelum
    fprintf('Kecenderungan : SNR meningkat setelah filtering diterapkan.\n');
else
    fprintf('Kecenderungan : SNR tidak meningkat, perlu ditinjau ulang parameter filter.\n');
end

%% --- 7. SIMPAN WORKSPACE (dipakai skrip 02) ---
save('ppg_workspace.mat', 'nama_file','time_ms','time_s','ppg_raw','ppg_detrend','ppg_norm', ...
     'ppg_filtered','ppg_filtered_norm','fs','fs_terukur','dt_ms','dt_ms_terukur', ...
     'f','P1','P1_dB','SNR_dB_sebelum','SNR_dB_sesudah','f_dominan','HR_dari_FFT', ...
     'f_low','f_high','orde_filter','b','a','baseline');

fprintf('\n[SKRIP 1 SELESAI] Workspace disimpan: ppg_workspace.mat\n');
