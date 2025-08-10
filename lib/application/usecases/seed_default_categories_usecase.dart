import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';

class SeedDefaultCategoriesUseCase {
  final CategoryRepository repo;
  SeedDefaultCategoriesUseCase(this.repo);

  Future<void> execute() async {
    final defaults = [
      // 'ENTREE',
      // 'SORTIE'
    ];
    final existing = await repo.findAllActive();
    final have = existing.map((e) => e.code).toSet();
    final now = DateTime.now();
    for (final code in defaults) {
      if (have.contains(code)) continue;
      final c = Category(
        id: const Uuid().v4(),
        code: code,
        description: code.replaceAll('_', ' '),
        createdAt: now,
        updatedAt: now,
        version: 0,
        isDirty: true,
      );
      await repo.create(c);
    }
  }
}
