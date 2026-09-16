# Supabase Multi-Device Sync (scaffold)

Status: **belum diimplementasikan**. `lib/services/cloud_sync_service.dart` hanya
kerangka. Dokumen ini merinci skema, keamanan, dan strategi konflik yang harus
dipakai saat mengaktifkan sinkronisasi.

## 1. Prasyarat

- `supabase_flutter` sudah ada di `pubspec.yaml` dan `AuthService` sudah
  menginisialisasi Supabase bila `SUPABASE_URL` + `SUPABASE_ANON_KEY` di-set
  lewat `--dart-define`.
- Jalankan build dengan:
  ```
  flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  ```

## 2. Skema tabel

Semua tabel memakai `user_id = auth.uid()` dan kolom audit untuk sinkronisasi.

```sql
create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id bigint not null,            -- id Isar asli (untuk rekonsiliasi)
  is_expense boolean not null,
  amount bigint not null,
  wallet text not null,
  category text not null,
  transaction_date timestamptz not null,
  is_cleared boolean not null default true,
  note text not null default '',
  receipt_path text not null default '',
  transfer_group_id text not null default '',
  currency text not null default 'IDR',
  deleted_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create table if not exists recurring_bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id bigint not null,
  name text not null,
  amount bigint not null,
  due_day int not null,
  deleted_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create table if not exists debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id bigint not null,
  name text not null,
  is_receivable boolean not null default false,
  principal bigint not null,
  remaining bigint not null,
  due_date timestamptz,
  note text not null default '',
  is_settled boolean not null default false,
  deleted_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create index if not exists transactions_user_updated_idx
  on transactions (user_id, updated_at);
```

## 3. Row-Level Security

```sql
alter table transactions enable row level security;
alter table recurring_bills enable row level security;
alter table debts enable row level security;

create policy "own rows" on transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own rows" on recurring_bills
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own rows" on debts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

## 4. Strategi konflik

Gunakan **last-write-wins per baris** dengan `updated_at` dari server:

- Lokal menyimpan `pendingSync` dan `updatedAt` per record.
- Push: `upsert` berdasarkan `(user_id, client_id)`, set `deleted_at` untuk
  penghapusan (soft delete), lalu simpan `updated_at` dari respons server.
- Pull: ambil baris dengan `updated_at > lastPulledAt`, bandingkan `updated_at`
  dengan record lokal; yang lebih baru menang.
- `transfer_group_id` dipakai untuk menjaga kedua kaki transfer tetap utuh,
  termasuk saat menghapus dari perangkat lain.

## 5. Langkah implementasi

1. Tambah `updatedAt`/`pendingSync`/`deletedAt` pada model Isar + migrasi.
2. Implement `pushPending()` dan `pullChanges()` di `CloudSyncService`.
3. Panggil dari `main.dart` sebagai startup step opsional dan setelah setiap
   mutasi (debounce).
4. Tangani kegagalan jaringan: simpan antrean, jangan blokir UI lokal.
