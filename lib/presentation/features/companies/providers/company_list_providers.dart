import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import 'package:jaayko/domain/company/repositories/company_repository.dart';
import 'package:jaayko/presentation/app/providers.dart';

import '../../../app/providers/company_repo_provider.dart';

final companySearchProvider = StateProvider<String>((_) => '');
final companyPageSizeProvider = Provider<int>((_) => 30);
final companyPageIndexProvider = StateProvider<int>((_) => 0);

final companyListProvider = FutureProvider<List<Company>>((ref) async {
  final repo = ref.read(companyRepoProvider);
  final search = ref.watch(companySearchProvider);
  final page = ref.watch(companyPageIndexProvider);
  final size = ref.watch(companyPageSizeProvider);
  return repo.findAll(
    CompanyQuery(
      search: search.trim().isEmpty ? null : search,
      limit: size,
      offset: page * size,
      onlyActive: true,
    ),
  );
});

final companyCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(companyRepoProvider);
  final search = ref.watch(companySearchProvider);
  return repo.count(
    CompanyQuery(
      search: search.trim().isEmpty ? null : search,
      onlyActive: true,
    ),
  );
});
