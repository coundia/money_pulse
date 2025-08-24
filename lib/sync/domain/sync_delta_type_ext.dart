/* Helpers to convert between string operation and SyncDeltaType. */
import 'sync_delta_type.dart';

extension SyncDeltaTypeExt on SyncDeltaType {
  String get op => name.toUpperCase(); // CREATE / UPDATE / DELETE

  static SyncDeltaType? fromOp(String? op) {
    if (op == null) return null;
    final s = op.toUpperCase().trim();
    switch (s) {
      case 'CREATE':
        return SyncDeltaType.create;
      case 'UPDATE':
        return SyncDeltaType.update;
      case 'DELETE':
        return SyncDeltaType.delete;
      default:
        return null;
    }
  }
}
