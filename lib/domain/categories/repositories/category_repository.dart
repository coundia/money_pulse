import '../entities/category.dart';

abstract class CategoryRepository {
  Future<Category> create(Category category);
  Future<void> update(Category category);
  Future<Category?> findById(String id);
  Future<Category?> findByCode(String code);
  Future<List<Category>> findAllActive();
  Future<void> softDelete(String id);
}
