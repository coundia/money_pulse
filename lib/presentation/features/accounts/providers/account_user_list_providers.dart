/* Riverpod providers to load and search account members ordered by updatedAt desc. */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/features/accounts/providers/account_user_repo_provider.dart';
import 'package:jaayko/domain/accounts/entities/account_user.dart';

final accountUserSearchProvider = StateProvider<String>((ref) => '');

final accountUserListProvider =
    FutureProvider.family<List<AccountUser>, String>((ref, accountId) async {
      final q = ref.watch(accountUserSearchProvider);
      final repo = ref.read(accountUserRepoProvider);
      return repo.listByAccount(accountId, q: q.isEmpty ? null : q);
    });
