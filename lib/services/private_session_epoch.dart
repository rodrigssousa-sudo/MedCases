/// Process-local generation shared by authentication, private loaders and cache.
/// Even logout followed by login to the same UID invalidates pending work.
abstract final class PrivateSessionEpoch {
  static int _value = 0;
  static int get current => _value;
  static void invalidate() {
    _value++;
  }
}
