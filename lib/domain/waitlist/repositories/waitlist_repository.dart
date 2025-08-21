/* Waitlist repository abstraction. */
import '../entities/waitlist_entry.dart';

abstract class WaitlistRepository {
  Future<void> save(WaitlistEntry entry);
  Future<WaitlistEntry?> load();
  Future<void> clear();
}
