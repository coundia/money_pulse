import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/app/providers.dart';

import '../../../app/providers/company_repo_provider.dart';

final companyByIdProvider = FutureProvider.family<Company?, String>((
  ref,
  id,
) async {
  final repo = ref.read(companyRepoProvider);
  return repo.findById(id);
});
