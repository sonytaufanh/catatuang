# Data Safety Mapping (CatatUang)

## Data Collected
1. Transaction data (income/expense, date, category, wallet, note).
2. Recurring bills (name, amount, due day).
3. App preferences (language, theme, currency, notification settings).
4. Security settings (biometric toggle, passcode enabled).

## Data Storage
- Default: local device storage (Isar, SharedPreferences, SecureStorage).
- Backup: local encrypted backup file.
- Cloud auth: optional when Supabase configured.

## Data Shared
- Tidak ada data yang dijual ke pihak ketiga.
- Tidak ada ad network tracking aktif.
- Crash reporting opsional via Sentry (hanya aktif bila `SENTRY_DSN` di-set):
  mengirim stack trace + konteks perangkat. Tidak mengirim transaksi/keuangan.
- Analytics produk bersifat lokal; tidak ada pengiriman ke server pihak ketiga.

## Data Storage Detail
- Database lokal `catatuang.db` memakai **SQLite + SQLCipher** (terenkripsi
  at-rest) dengan kunci 32-byte yang disimpan di secure storage perangkat.
- `flutter_secure_storage`: PIN/password hash (PBKDF2), kunci backup.
- `SharedPreferences`: preferensi, sesi lokal, saldo awal, anggaran.
- Backup: file JSON terenkripsi di dokumen aplikasi (AES-GCM).

## User Controls
- Menu Profil -> Keamanan -> **Hapus Semua Data** menghapus seluruh data lokal,
  profil, dan backup di perangkat.
- Clear app data / uninstall.
- Matikan notifikasi, ganti/hapus PIN, matikan auto backup.
- Ekspor laporan (CSV/PDF) dan ekspor kunci backup kapan saja.
