import 'loose_exception.dart';

class DocumentResponse<T> {
  final String _name;
  final String _createTime;
  final String _updateTime;
  final T? _entity;

  factory DocumentResponse(T entity, Map<String, dynamic> firestoreObject) {
    final name = (firestoreObject['name'] ?? '') as String;
    final createTime = (firestoreObject['createTime'] ?? '') as String;
    final updateTime = (firestoreObject['updateTime'] ?? '') as String;
    return DocumentResponse._(entity, name, createTime, updateTime);
  }

  const DocumentResponse._(
      this._entity, this._name, this._createTime, this._updateTime);
  // const DocumentResponse._empty(
  //     [this._entity, this._name, this._createTime, this._updateTime]);

  const DocumentResponse._empty()
      : _name = '',
        _createTime = '',
        _updateTime = '',
        _entity = null;

  static DocumentResponse<T> empty<T>() => DocumentResponse._empty();

  String get name => _name;
  String get id => _name.split('/').last;
  DateTime get createTime => DateTime.parse(_createTime);
  DateTime get updateTime => DateTime.parse(_updateTime);
  T? get entity => _entity;

  bool get isEmpty {
    return (_entity == null) &&
        _name.isEmpty &&
        _createTime.isEmpty &&
        _updateTime.isEmpty;
  }

  bool get isNotEmpty => !isEmpty;

  // static const DocumentResponse empty = DocumentResponse._empty();
}
