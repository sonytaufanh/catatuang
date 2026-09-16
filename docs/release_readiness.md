# Release Readiness (CatatUang)

Status per build `1.1.0+2`. "Done" berarti sudah ada di repo dan terverifikasi di
lingkungan pengembangan (analyze + test + build rilis Android).

## Sudah done
- [x] `flutter analyze` bersih, unit/widget test hijau.
- [x] Build `flutter build apk --release` dan `flutter build appbundle --release` berhasil.
- [x] Migrasi database dari Isar ke **SQLite + SQLCipher** (`sqflite_sqlcipher`),
      terenkripsi at-rest dengan kunci di secure storage; dependensi `isar`
      (arsip) dan plugin lokal dihapus.
- [x] Test layer database (CRUD, transfer, split, agregasi, stream, backup).
- [x] Signing rilis via `android/key.properties` (fallback debug untuk CI).
- [x] Hashing PIN/password dengan PBKDF2-HMAC-SHA256 + salt + constant-time.
- [x] Migrasi hash lama (SHA-256 / plaintext) otomatis saat verifikasi sukses.
- [x] Biometrik *fail closed* dan aksi sensitif butuh verifikasi.
- [x] Mode PIN-only benar-benar mengunci aplikasi.
- [x] Menu Hapus Semua Data (konfirmasi ketik + PIN/biometrik).
- [x] Crash reporting opsional via Sentry (`SENTRY_DSN`).
- [x] Backup/restore mencakup transaksi, tagihan, utang, template, anggaran, target.
- [x] CI: analyze + test + build APK.

## Gate eksternal (harus dipenuhi sebelum produksi)
- [x] **Enkripsi DB**: aktif via SQLite + SQLCipher + kunci 32-byte di secure storage.
- [ ] **iOS build & signing**: harus di macOS (tidak bisa di Windows).
- [ ] **Sentry DSN**: buat project, isi `--dart-define=SENTRY_DSN=...` di CI/rilis.
- [ ] **Privacy Policy & Terms URL** live + Data Safety Play + content rating.
- [ ] **Uji migrasi skema** versi lama -> baru pada perangkat nyata.
- [ ] **Integration test** flow uang kritis (butuh emulator/perangkat).
- [ ] **Profiling performa** di perangkat low-end (Home/Stats).
- [ ] **Kebijakan izin**: SMS/widget belum diaktifkan; siapkan justifikasi bila dipakai.

## Perintah rilis
```powershell
# Rilis Android (AAB untuk Play Store)
flutter build appbundle --release --dart-define=SENTRY_DSN=<dsn>

# APK per ABI (ukuran lebih kecil)
flutter build apk --release --split-per-abi --dart-define=SENTRY_DSN=<dsn>
```

Untuk signing asli, salin `android/key.properties.example` menjadi
`android/key.properties` dan isi nilai keystore (file ini git-ignored).
