import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

class EnsureDefaultAccountUseCase {
  final AccountRepository repo;
  final String code;
  final String description;
  final String currency;

  EnsureDefaultAccountUseCase(
    this.repo, {
    this.code = 'Main',
    this.description = '',
    this.currency = 'XOF',
  });

  Future<Account> execute() async {
    final items = await repo.findAllActive();
    if (items.isEmpty) {
      final now = DateTime.now();
      final a = Account(
        id: const Uuid().v4(),
        remoteId: null,
        balance: 0,
        balancePrev: 0,
        balanceBlocked: 0,
        code: code,
        description: description,
        status: null,
        currency: currency,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        version: 0,
        isDirty: true,
      );
      await repo.create(a);
      await repo.setDefault(a.id);
      return a;
    }

    final def = await repo.findDefault();
    if (def != null) return def;

    final first = items.first;
    await repo.setDefault(first.id);
    return first;
  }
}
