import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/company/repositories/company_repository.dart';
import 'package:money_pulse/infrastructure/company/repositories/company_repository_sqflite.dart';
import 'package:money_pulse/presentation/app/providers.dart';

final companyRepoProvider = Provider<CompanyRepository>((ref) {
  // Si ton provider DB s'appelle `dbProvider`, remplace la ligne suivante.
  final db = ref.read(dbProvider);
  return CompanyRepositorySqflite(db);
});
