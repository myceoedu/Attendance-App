/// No-op on non-web. [WebBlankTab.open] always returns null.
class WebBlankTab {
  const WebBlankTab._();

  /// Call synchronously in the tap handler (before any `await`).
  static WebBlankTab? open() => null;

  bool goTo(String url) => false;

  void close() {}
}
