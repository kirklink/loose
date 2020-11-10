class FieldReference {
  final String name;
  const FieldReference(this.name);
  Map<String, String> get encode => {'fieldPath': name};
}
