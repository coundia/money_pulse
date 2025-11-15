// Data providers for filters (company options).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import '../../../../domain/company/repositories/company_repository.dart';
import '../../../app/providers/company_repo_provider.dart';

final companyFilterOptionsProvider = FutureProvider<List<Company>>((ref) async {
  final repo = ref.read(companyRepoProvider);
  final list = await repo.findAll(const CompanyQuery(limit: 500, offset: 0));
  list.sort(
    (a, b) => (a.name ?? a.code ?? '').toLowerCase().compareTo(
      (b.name ?? b.code ?? '').toLowerCase(),
    ),
  );
  return list;
});
