# sync

- `domain/` : DTOs et types de deltas pour chaque table.
- `infrastructure/` : client HTTP `SyncApiClient`.
- `application/` : use cases par table (`PushXUseCase`) + orchestrateur `SyncAllUseCase`.
- `sync_service_provider.dart` : wiring Riverpod et `syncAllTables(ref)`.

Pré-requis côté repositories :
- Chaque repo doit exposer `findDirty({limit})` ordonné par `updatedAt DESC` et `markSynced(ids, syncedAt)` qui met `isDirty=0` et `syncAt`.
- Types de clés :
  - UUID `String` pour la plupart des tables; `int` pour `stock_level` et `stock_movement`.
- Endpoints attendus :
  - `/api/v1/commands/{entity}/sync` pour: category, balance, transaction, unit, product, transaction-item, company, customer, debt, stock-level, stock-movement.
