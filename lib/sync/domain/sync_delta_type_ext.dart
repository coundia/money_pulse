// lib/sync/domain/sync_delta_type_ext.dart
import 'package:jaayko/sync/domain/sync_delta_type.dart';

extension SyncDeltaTypeExt on SyncDeltaType {
  String get op => switch (this) {
    SyncDeltaType.create => 'CREATE',
    SyncDeltaType.update => 'UPDATE',
    SyncDeltaType.delete => 'DELETE',
  };

  static SyncDeltaType fromOp(String? opStr, {bool deleted = false}) {
    final s = (opStr ?? '').toUpperCase();
    if (s == 'CREATE') return SyncDeltaType.create;
    if (s == 'DELETE') return SyncDeltaType.delete;
    if (s == 'UPDATE') return SyncDeltaType.update;
    // Fallback : si l’entité est supprimée
    return deleted ? SyncDeltaType.delete : SyncDeltaType.update;
  }
}
