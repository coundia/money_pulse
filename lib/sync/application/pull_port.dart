/* PullPort interface: a pull use case must implement execute() returning number of upserts. */
abstract class PullPort {
  Future<int> execute();
}
