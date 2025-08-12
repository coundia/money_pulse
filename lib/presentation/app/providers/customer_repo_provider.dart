import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/customer/repositories/customer_repository.dart';
import 'package:money_pulse/infrastructure/customer/repositories/customer_repository_sqflite.dart';
import 'package:money_pulse/presentation/app/providers.dart';

final customerRepoProvider = Provider<CustomerRepository>((ref) {
  // Si ton provider DB s'appelle `dbProvider`, remplace la ligne suivante.
  final db = ref.read(dbProvider);
  return CustomerRepositorySqflite(db);
});
