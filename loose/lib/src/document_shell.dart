class DocumentShell<T> {
  final String _name;
  final String _createTime;
  final String _updateTime;
  final T _entity;

  DocumentShell(
      [this._entity,
      this._name = '',
      this._createTime = '',
      this._updateTime = '']);
  // DocumentShell.fromFS(this._entity, this._name, this._createTime, this._updateTime);
  // const DocumentShell._empty(this._entity = null, );

  const DocumentShell._empty(
      [this._entity,
      this._name = '',
      this._createTime = '',
      this._updateTime = '']);

  static DocumentShell<T> empty<T>() => DocumentShell._empty();

  String get name => _name;
  String get id => _name.split('/').last;
  DateTime get createTime => DateTime.parse(_createTime);
  DateTime get updateTime => DateTime.parse(_updateTime);
  T get entity => _entity;
  bool get isEmpty {
    return (_entity == null) &&
        _name.isEmpty &&
        _createTime.isEmpty &&
        _updateTime.isEmpty;
  }

  bool get isNotEmpty => !isEmpty;
}
