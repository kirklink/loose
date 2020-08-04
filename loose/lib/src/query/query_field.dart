import 'package:googleapis/androidmanagement/v1.dart';
import 'package:loose/src/reference.dart';
import 'package:loose/src/query/field_reference.dart';
import 'package:googleapis/firestore/v1.dart' as fs;

abstract class QueryField<T> {
  FieldReference _field;
  QueryField(String name) {
    _field = FieldReference(name);
  }
  Map<String, String> get result => _field.result;
  fs.Value compare(T comparable);
}

class StringField extends QueryField<String> {

  StringField(String name) : super(name);
  
  @override
  fs.Value compare(String string) {
    return (fs.Value()..stringValue = string);
  }
}

class IntegerField extends QueryField<int> {

  IntegerField(String name) : super(name);
  
  @override
  fs.Value compare(int integer) {
    return (fs.Value()..integerValue = integer.toString());
  }
}

class DoubleField extends QueryField<double> {

  DoubleField(String name) : super(name);

  @override
  fs.Value compare(double float) {
    return (fs.Value()..doubleValue = float);
  }

}

class BoolField extends QueryField<bool> {

  BoolField(String name) : super(name);

  @override
  fs.Value compare(bool boolean) {
    return (fs.Value()..booleanValue = boolean);
  }
}

class DateTimeField extends QueryField<DateTime> {

  DateTimeField(String name) : super(name);

  @override
  fs.Value compare(DateTime datetime) {
    return (fs.Value()..timestampValue = datetime.toIso8601String());
  }

}

class ReferenceField extends QueryField<Reference> {
  ReferenceField(String name) : super(name);

  @override
  fs.Value compare(Reference reference) {
    return (fs.Value()..referenceValue = reference.toString());
  }
}

typedef ValueMapper<T> = fs.Value Function(T element);

class ArrayField<T> extends QueryField<T> {

  final ValueMapper<T> _mapper;

  ArrayField(String name, this._mapper) : super(name);

  @override
  fs.Value compare(T element) {
    return (_mapper(element));
  }

}