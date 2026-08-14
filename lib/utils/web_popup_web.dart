import 'package:web/web.dart' as web;

/// Opens a blank tab in the same user click so Chrome will not block it
/// after an async signed-URL fetch.
class WebBlankTab {
  WebBlankTab._(this._window);

  final web.Window _window;

  /// Call synchronously in the tap handler (before any `await`).
  static WebBlankTab? open() {
    final window = web.window.open('about:blank', '_blank');
    if (window == null) return null;
    return WebBlankTab._(window);
  }

  bool goTo(String url) {
    _window.location.href = url;
    return true;
  }

  void close() => _window.close();
}
