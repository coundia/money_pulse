/* Orchestrates all push use cases in FK-safe order, consults SyncPolicy, logs, returns a summary. */
import 'push_port.dart';
import '../infrastructure/sync_logger.dart';
import 'sync_policy.dart';
import 'package:money_pulse/sync/domain/sync_domain.dart';

class SyncSummary {
  final int categories;
  final int accounts;
  final int transactions;
  final int units;
  final int products;
  final int items;
  final int companies;
  final int customers;
  final int debts;
  final int stockLevels;
  final int stockMovements;

  const SyncSummary({
    required this.categories,
    required this.accounts,
    required this.transactions,
    required this.units,
    required this.products,
    required this.items,
    required this.companies,
    required this.customers,
    required this.debts,
    required this.stockLevels,
    required this.stockMovements,
  });

  SyncSummary copyWith({
    int? categories,
    int? accounts,
    int? transactions,
    int? units,
    int? products,
    int? items,
    int? companies,
    int? customers,
    int? debts,
    int? stockLevels,
    int? stockMovements,
  }) {
    return SyncSummary(
      categories: categories ?? this.categories,
      accounts: accounts ?? this.accounts,
      transactions: transactions ?? this.transactions,
      units: units ?? this.units,
      products: products ?? this.products,
      items: items ?? this.items,
      companies: companies ?? this.companies,
      customers: customers ?? this.customers,
      debts: debts ?? this.debts,
      stockLevels: stockLevels ?? this.stockLevels,
      stockMovements: stockMovements ?? this.stockMovements,
    );
  }
}

class SyncAllUseCase {
  final PushPort categories;
  final PushPort accounts;
  final PushPort transactions;
  final PushPort units;
  final PushPort products;
  final PushPort items;
  final PushPort companies;
  final PushPort customers;
  final PushPort debts;
  final PushPort stockLevels;
  final PushPort stockMovements;
  final SyncPolicy policy;
  final SyncLogger logger;

  SyncAllUseCase({
    required this.categories,
    required this.accounts,
    required this.transactions,
    required this.units,
    required this.products,
    required this.items,
    required this.companies,
    required this.customers,
    required this.debts,
    required this.stockLevels,
    required this.stockMovements,
    required this.policy,
    required this.logger,
  });

  Future<SyncSummary> syncAll({int batchSize = 200}) async {
    logger.info('Sync start');

    final accs = await _maybe(
      SyncDomain.accounts,
      () => accounts.execute(batchSize: batchSize),
    );
    final cats = await _maybe(
      SyncDomain.categories,
      () => categories.execute(batchSize: batchSize),
    );
    final uts = await _maybe(
      SyncDomain.units,
      () => units.execute(batchSize: batchSize),
    );
    final comps = await _maybe(
      SyncDomain.companies,
      () => companies.execute(batchSize: batchSize),
    );
    final prods = await _maybe(
      SyncDomain.products,
      () => products.execute(batchSize: batchSize),
    );
    final custs = await _maybe(
      SyncDomain.customers,
      () => customers.execute(batchSize: batchSize),
    );
    final dbts = await _maybe(
      SyncDomain.debts,
      () => debts.execute(batchSize: batchSize),
    );
    final sls = await _maybe(
      SyncDomain.stockLevels,
      () => stockLevels.execute(batchSize: batchSize),
    );
    final sms = await _maybe(
      SyncDomain.stockMovements,
      () => stockMovements.execute(batchSize: batchSize),
    );
    final txs = await _maybe(
      SyncDomain.transactions,
      () => transactions.execute(batchSize: batchSize),
    );
    final itms = await _maybe(
      SyncDomain.items,
      () => items.execute(batchSize: batchSize),
    );

    logger.info('Sync done');
    return SyncSummary(
      categories: cats,
      accounts: accs,
      transactions: txs,
      units: uts,
      products: prods,
      items: itms,
      companies: comps,
      customers: custs,
      debts: dbts,
      stockLevels: sls,
      stockMovements: sms,
    );
  }

  Future<int> _maybe(SyncDomain domain, Future<int> Function() run) async {
    if (!policy.enabled(domain)) {
      logger.info('Sync ${domain.key}: disabled');
      return 0;
    }
    try {
      logger.info('Sync ${domain.key}: start');
      final n = await run();
      logger.info('Sync ${domain.key}: ok count=$n');
      return n;
    } catch (e, st) {
      logger.error('Sync ${domain.key}: error', e, st);
      rethrow;
    }
  }
}
