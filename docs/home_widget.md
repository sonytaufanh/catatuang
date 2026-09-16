# Home Screen Widget — scaffold

Status: **belum diimplementasikan**. Widget membutuhkan plugin + konfigurasi
native (Android/iOS), jadi perlu keputusan produk dan setup platform.

## Rekomendasi

Gunakan paket `home_widget` (mendukung Android App Widget + iOS WidgetKit).

1. Tambahkan `home_widget` ke `pubspec.yaml`.
2. Android: buat `AppWidgetProvider` + layout XML di
   `android/app/src/main/res/`, daftarkan di `AndroidManifest.xml`.
3. iOS: tambahkan Widget Extension lewat Xcode, aktifkan App Group untuk
   berbagi data.
4. Isi data dari `main.dart` setelah startup dan setelah mutasi transaksi:
   ```dart
   await HomeWidget.saveWidgetData<String>('balance', formattedBalance);
   await HomeWidget.updateWidget(name: 'BalanceWidget');
   ```

## Data yang cocok ditampilkan

- Saldo aktif (semua dompet).
- "Aman belanja hari ini" dari `ForecastService` (lihat `lib/services/forecast_service.dart`).
- Tombol pintas "Tambah transaksi" (deep link ke `AddTransactionScreen`).

## Catatan

- Jangan tampilkan angka saldo di widget default saat pengguna mengaktifkan
  mode privasi/biometric lock.
- Sinkronkan widget saat transaksi berubah; karena `transactionsNotifier` sudah
  reaktif (lihat `lib/data/transaction_store.dart`), cukup pasang listener dan
  panggil `HomeWidget.updateWidget`.
