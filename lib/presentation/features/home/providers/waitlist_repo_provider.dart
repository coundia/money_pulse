/* Riverpod providers for waitlist repository and current entry. */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/waitlist/repositories/waitlist_repository.dart';
import 'package:money_pulse/infrastructure/waitlist/repositories/waitlist_repository_prefs.dart';
import 'package:money_pulse/domain/waitlist/entities/waitlist_entry.dart';

final waitlistRepoProvider = Provider<WaitlistRepository>((ref) {
  return WaitlistRepositoryPrefs();
});

final waitlistEntryProvider = FutureProvider<WaitlistEntry?>((ref) async {
  final repo = ref.read(waitlistRepoProvider);
  return repo.load();
});
