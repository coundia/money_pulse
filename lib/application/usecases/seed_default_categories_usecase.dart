import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';

class SeedDefaultCategoriesUseCase {
  final CategoryRepository repo;
  SeedDefaultCategoriesUseCase(this.repo);

  Future<void> execute() async {
    final existing = await repo.findAllActive();

    if (existing.isNotEmpty) {
      return;
    }

    final defaults = [
      //sortie
      {'code': 'Courses', 'type': 'DEBIT'},
      {'code': 'Loyer', 'type': 'DEBIT'},
      {'code': 'Transport', 'type': 'DEBIT'},
      {'code': 'Internet', 'type': 'DEBIT'},
      {'code': 'Eau', 'type': 'DEBIT'},
      {'code': 'Electricité', 'type': 'DEBIT'},
      {'code': 'Dons', 'type': 'DEBIT'},
      {'code': 'Achat', 'type': 'DEBIT'},
      //entree
      {'code': 'salaire', 'type': 'CREDIT'},
      {'code': 'remboursement', 'type': 'CREDIT'},
      {'code': 'vente', 'type': 'CREDIT'},
      {'code': 'cadeaux', 'type': 'CREDIT'},
      {'code': 'prestations', 'type': 'CREDIT'},
    ];

    final have = existing.map((e) => e.code).toSet();
    final now = DateTime.now();
    for (final def in defaults) {
      if (have.contains(def['code'])) continue;
      final c = Category(
        id: const Uuid().v4(),
        code: def['code']!.toUpperCase(),
        description: def['code']!.replaceAll('_', ' '),
        createdAt: now,
        updatedAt: now,
        typeEntry: def['type']!,
        version: 0,
        isDirty: true,
      );
      await repo.create(c);
    }
  }
}
