import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/app/providers.dart';

import '../../../app/providers/company_repo_provider.dart';
import '../../../app/providers/customer_repo_provider.dart';

final customerByIdProvider = FutureProvider.family<Customer?, String>((
  ref,
  id,
) async {
  final repo = ref.read(customerRepoProvider);
  return repo.findById(id);
});

final companyOfCustomerProvider = FutureProvider.family<Company?, String?>((
  ref,
  companyId,
) async {
  if (companyId == null || companyId.isEmpty) return null;
  final repo = ref.read(companyRepoProvider);
  return repo.findById(companyId);
});
