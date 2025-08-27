/* Domain enumeration for syncable aggregates. */
enum SyncDomain {
  categories,
  accounts,
  transactions,
  units,
  products,
  items,
  companies,
  customers,
  debts,
  stockLevels,
  stockMovements,
  accountUsers,
}

extension SyncDomainKey on SyncDomain {
  String get key {
    switch (this) {
      case SyncDomain.categories:
        return 'categories';
      case SyncDomain.accounts:
        return 'accounts';
      case SyncDomain.transactions:
        return 'transactions';
      case SyncDomain.units:
        return 'units';
      case SyncDomain.products:
        return 'products';
      case SyncDomain.items:
        return 'items';
      case SyncDomain.companies:
        return 'companies';
      case SyncDomain.customers:
        return 'customers';
      case SyncDomain.debts:
        return 'debts';
      case SyncDomain.stockLevels:
        return 'stockLevels';
      case SyncDomain.stockMovements:
        return 'stockMovements';
      case SyncDomain.accountUsers:
        return 'accountUsers';
    }
  }
}
