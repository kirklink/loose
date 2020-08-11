import 'package:googleapis/androidmanagement/v1.dart';
import 'package:loose/src/reference.dart';
import 'package:loose/src/query/field_reference.dart';
import 'package:googleapis/firestore/v1.dart' as fs;

abstract class QueryField<T> {
  FieldReference _field;
  QueryField(String name) {
    _field = FieldReference(name);
  }
  Map<String, String> get result => _field.encode;
  Map<String, Object> compare(T comparable);
}

class StringField extends QueryField<String> {

  StringField(String name) : super(name);
  
  @override
  Map<String, Object> compare(String string) {
    return {'stringValue': string};
  }
}

class IntegerField extends QueryField<int> {

  IntegerField(String name) : super(name);
  
  @override
  Map<String, Object> compare(int integer) {
    return {'integerValue': integer.toString()};
  }
}

class DoubleField extends QueryField<double> {

  DoubleField(String name) : super(name);

  @override
  Map<String, Object> compare(double float) {
    return {'doubleValue': float};
  }

}

class BoolField extends QueryField<bool> {

  BoolField(String name) : super(name);

  @override
  Map<String, Object> compare(bool boolean) {
    return {'booleanValue': boolean};
  }
}

class DateTimeField extends QueryField<DateTime> {

  DateTimeField(String name) : super(name);

  @override
  Map<String, Object> compare(DateTime datetime) {
    return {'timestampValue': datetime.toIso8601String()};
  }

}

class ReferenceField extends QueryField<Reference> {
  ReferenceField(String name) : super(name);

  @override
  Map<String, Object> compare(Reference reference) {
    return {'referenceValue': reference.toString()};
  }
}

typedef ValueMapper<T> = Map<String, Object> Function(T element);

class ArrayField<T> extends QueryField<T> {

  final ValueMapper<T> _mapper;

  ArrayField(String name, this._mapper) : super(name);

  @override
  Map<String, Object> compare(T element) {
    return (_mapper(element));
  }

}