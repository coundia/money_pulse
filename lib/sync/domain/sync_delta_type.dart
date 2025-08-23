/* Defines the delta type for remote sync payloads. */
enum SyncDeltaType { create, update, delete }

extension SyncDeltaTypeWire on SyncDeltaType {
  String get wire {
    switch (this) {
      case SyncDeltaType.create:
        return 'CREATE';
      case SyncDeltaType.update:
        return 'UPDATE';
      case SyncDeltaType.delete:
        return 'DELETE';
    }
  }
}
