# SMS Import (Android) — scaffold

`lib/services/sms_import_service.dart` sudah berisi parser SMS yang murni dan
teruji (`test/services/sms_import_service_test.dart`). Yang belum ada adalah
listener platform yang membaca SMS masuk.

## Yang sudah tersedia

- `SmsImportService.parse(body, now:)` -> `ImportedTransaction?`
  - mendeteksi nominal (mengabaikan "Saldo"),
  - mendeteksi debit/kredit,
  - menebak kategori via `TransactionImportService.guessCategory`,
  - mengekstrak tanggal bila ada.

## Yang perlu ditambahkan

1. **Plugin**: tambahkan `telephony` (atau platform channel sendiri) ke
   `pubspec.yaml`, lalu `flutter pub get`.
2. **Izin** di `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.RECEIVE_SMS" />
   <uses-permission android:name="android.permission.READ_SMS" />
   ```
   Jalankan permintaan izin runtime sebelum mendengarkan SMS.
3. **Listener**: dengarkan SMS dari nomor bank/ewallet, lalu:
   ```dart
   final candidate = SmsImportService.instance.parse(message.body);
   if (candidate != null) {
     await DatabaseService.instance.addTransaction(
       isExpense: candidate.isExpense,
       amount: candidate.amount,
       wallet: 'bank',
       category: candidate.category,
       transactionDate: candidate.date,
       isCleared: true,
       note: candidate.description,
     );
     await refreshTransactions();
   }
   ```
4. **Review queue (disarankan)**: jangan langsung menulis. Simpan kandidat ke
   antrean, tampilkan notifikasi/layar konfirmasi agar pengguna bisa memilih
   dompet/kategori sebelum disimpan.

## Privasi & kepatuhan

- SMS berisi data finansial sensitif. Jelaskan di kebijakan privasi bahwa SMS
  diproses **di perangkat** dan tidak dikirim ke server.
- Hanya proses SMS dari pengirim yang di-whitelist pengguna.
- Sediakan tombol untuk menonaktifkan pemrosesan SMS.
- Google Play membatasi izin SMS; siapkan justifikasi kebijakan (gunakan
  `READ_SMS` hanya jika benar-benar diperlukan, atau andalkan notifikasi
  (NotificationListener) sebagai alternatif yang lebih ringan izinnya).
