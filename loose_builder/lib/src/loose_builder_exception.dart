class LooseBuilderException implements Exception {
  String cause;
  LooseBuilderException(this.cause);

  String toString() => cause;
}
