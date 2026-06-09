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

## User Controls
- Hapus data via clear app data / restore flow.
- Matikan notifikasi kapan saja.
- Ganti/hapus PIN keamanan.
