import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Scaffold for optional multi-device sync over Supabase.
///
/// The concrete schema, row-level-security policies and conflict strategy are
/// documented in `docs/supabase_sync.md`. This class intentionally performs no
/// work until [isAvailable] is true (Supabase configured + user signed in),
/// and the push/pull methods are still to be implemented.
class CloudSyncService {
  CloudSyncService._();

  static final CloudSyncService instance = CloudSyncService._();

  bool get isConfigured => AuthService.instance.isConfigured;

  bool get isAvailable {
    if (!isConfigured) return false;
    return Supabase.instance.client.auth.currentUser != null;
  }

  /// Pushes local changes since the last sync cursor. Not implemented yet.
  Future<int> pushPending() async {
    if (!isAvailable) return 0;
    // TODO(sync): upsert transactions/debts with updatedAt + deletedAt flags
    // using `Supabase.instance.client.from('transactions').upsert(...)`.
    throw UnimplementedError('Cloud sync belum diimplementasikan.');
  }

  /// Pulls remote changes and merges them into the local Isar database.
  Future<int> pullChanges() async {
    if (!isAvailable) return 0;
    // TODO(sync): fetch rows with updatedAt > lastPulledAt and apply
    // last-write-wins per record id, then refresh local stores.
    throw UnimplementedError('Cloud sync belum diimplementasikan.');
  }
}
