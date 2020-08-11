class FieldReference {
  final String _name;
  const FieldReference(this._name);
  Map<String, String> get encode => {'fieldPath': _name};
}