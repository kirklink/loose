class LooseException implements Exception {
  String cause;
  LooseException(this.cause);

  @override
  String toString() => cause;
}
