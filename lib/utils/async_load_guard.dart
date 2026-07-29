/// Prevents stale async loads from overwriting newer UI state.
///
/// Call [begin] at the start of each load; only apply results when
/// [isCurrent] still matches that generation.
class AsyncLoadGuard {
  int _generation = 0;

  int begin() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;

  void invalidate() => ++_generation;
}
