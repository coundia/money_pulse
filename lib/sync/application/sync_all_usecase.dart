/* Orchestrates all push use cases, logs steps, returns a summary. */
import 'push_port.dart';
import '../infrastructure/sync_logger.dart';

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
    required this.logger,
  });

  Future<SyncSummary> syncAll({int batchSize = 200}) async {
    logger.info('Sync start');
    final cats = await _run(
      'categories',
      () => categories.execute(batchSize: batchSize),
    );
    final accs = await _run(
      'accounts',
      () => accounts.execute(batchSize: batchSize),
    );
    final txs = await _run(
      'transactions',
      () => transactions.execute(batchSize: batchSize),
    );
    final uts = await _run('units', () => units.execute(batchSize: batchSize));
    final prods = await _run(
      'products',
      () => products.execute(batchSize: batchSize),
    );
    final itms = await _run('items', () => items.execute(batchSize: batchSize));
    final comps = await _run(
      'companies',
      () => companies.execute(batchSize: batchSize),
    );
    final custs = await _run(
      'customers',
      () => customers.execute(batchSize: batchSize),
    );
    final dbts = await _run('debts', () => debts.execute(batchSize: batchSize));
    final sls = await _run(
      'stockLevels',
      () => stockLevels.execute(batchSize: batchSize),
    );
    final sms = await _run(
      'stockMovements',
      () => stockMovements.execute(batchSize: batchSize),
    );
    logger.info(
      'Sync done: cats=$cats accs=$accs txs=$txs uts=$uts prods=$prods items=$itms comps=$comps custs=$custs debts=$dbts sl=$sls sm=$sms',
    );
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

  Future<int> _run(String name, Future<int> Function() fn) async {
    try {
      logger.info('Sync $name: start');
      final n = await fn();
      logger.info('Sync $name: ok count=$n');
      return n;
    } catch (e, st) {
      logger.error('Sync $name: error', e, st);
      rethrow;
    }
  }
}
