/* Abstractions for enabling/disabling sync per domain. */
import 'package:money_pulse/sync/domain/sync_domain.dart';

abstract class SyncPolicy {
  bool enabled(SyncDomain domain);
}

class AllowAllSyncPolicy implements SyncPolicy {
  @override
  bool enabled(SyncDomain domain) => true;
}

class DisabledSetSyncPolicy implements SyncPolicy {
  final Set<SyncDomain> disabled;
  const DisabledSetSyncPolicy(this.disabled);
  @override
  bool enabled(SyncDomain domain) => !disabled.contains(domain);
}
