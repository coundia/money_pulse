/* Common interface for push use cases consumed by SyncAllUseCase. */
abstract class PushPort {
  Future<int> execute({int batchSize});
}
