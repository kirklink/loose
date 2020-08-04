class LooseException implements Exception {
  String cause;
  LooseException(this.cause);

  String toString() => cause;
}
