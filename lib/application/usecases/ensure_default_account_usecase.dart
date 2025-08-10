import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

class EnsureDefaultAccountUseCase {
  final AccountRepository repo;
  EnsureDefaultAccountUseCase(this.repo);

  Future<Account> execute() async {
    final def = await repo.findDefault();
    if (def != null) return def;
    final now = DateTime.now();
    final a = Account(
      id: const Uuid().v4(),
      code: 'Main',
      description: 'Default',
      currency: 'XOF',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
      balance: 0,
      balancePrev: 0,
      balanceBlocked: 0,
      version: 0,
      isDirty: true,
    );
    await repo.create(a);
    await repo.setDefault(a.id);
    return a;
  }
}
