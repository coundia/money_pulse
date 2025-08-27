/* Orchestrates pull use cases in FK-safe order. All ports are optional and skipped if null, policy-driven. */
import '../infrastructure/sync_logger.dart';
import 'package:money_pulse/sync/domain/sync_domain.dart';
import 'sync_policy.dart';
import 'pull_port.dart';

class PullSummary {
  final int accounts;
  final int categories;
  final int units;
  final int companies;
  final int products;
  final int customers;
  final int debts;
  final int stockLevels;
  final int stockMovements;
  final int transactions;
  final int items;
  final int accountUsers; // ⬅️ added

  const PullSummary({
    required this.accounts,
    required this.categories,
    required this.units,
    required this.companies,
    required this.products,
    required this.customers,
    required this.debts,
    required this.stockLevels,
    required this.stockMovements,
    required this.transactions,
    required this.items,
    required this.accountUsers,
  });
}

class PullAllUseCase {
  final PullPort? accounts;
  final PullPort? categories;
  final PullPort? units;
  final PullPort? companies;
  final PullPort? products;
  final PullPort? customers;
  final PullPort? debts;
  final PullPort? stockLevels;
  final PullPort? stockMovements;
  final PullPort? transactions;
  final PullPort? items;
  final PullPort? accountUsers;

  final SyncPolicy policy;
  final SyncLogger logger;

  PullAllUseCase({
    this.accounts,
    this.categories,
    this.units,
    this.companies,
    this.products,
    this.customers,
    this.debts,
    this.stockLevels,
    this.stockMovements,
    this.transactions,
    this.items,
    required this.policy,
    required this.logger,
    this.accountUsers,
  });

  Future<PullSummary> pullAll() async {
    logger.info('Pull start');

    final accs = await _maybe(SyncDomain.accounts, accounts);
    final cats = await _maybe(SyncDomain.categories, categories);
    final uts = await _maybe(SyncDomain.units, units);
    final comps = await _maybe(SyncDomain.companies, companies);
    final prods = await _maybe(SyncDomain.products, products);
    final custs = await _maybe(SyncDomain.customers, customers);
    final dbts = await _maybe(SyncDomain.debts, debts);
    final sls = await _maybe(SyncDomain.stockLevels, stockLevels);
    final sms = await _maybe(SyncDomain.stockMovements, stockMovements);
    final txs = await _maybe(SyncDomain.transactions, transactions);
    final itms = await _maybe(SyncDomain.items, items);
    final aus = await _maybe(SyncDomain.accountUsers, accountUsers);

    logger.info('Pull done');
    return PullSummary(
      accounts: accs,
      categories: cats,
      units: uts,
      companies: comps,
      products: prods,
      customers: custs,
      debts: dbts,
      stockLevels: sls,
      stockMovements: sms,
      transactions: txs,
      items: itms,
      accountUsers: aus,
    );
  }

  Future<int> _maybe(SyncDomain domain, PullPort? uc) async {
    if (uc == null) {
      logger.info('Pull ${domain.key}: skipped (not wired)');
      return 0;
    }
    if (!policy.enabled(domain)) {
      logger.info('Pull ${domain.key}: disabled');
      return 0;
    }
    try {
      logger.info('Pull ${domain.key}: start');
      final n = await uc.execute();
      logger.info('Pull ${domain.key}: ok count=$n');
      return n;
    } catch (e, st) {
      logger.error('Pull ${domain.key}: error', e, st);
      rethrow;
    }
  }
}
