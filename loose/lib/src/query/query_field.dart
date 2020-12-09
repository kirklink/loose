import 'package:loose/src/reference.dart';
import 'package:loose/src/query/field_reference.dart';

abstract class QueryField<T> {
  final String name;
  QueryField(this.name);
  // String get name => _field.name;
  Map<String, String> get fieldPath => {'fieldPath': name};
  Map<String, Object> compare(T comparable);
}

abstract class QueryCompare<T> {}

// abstract class QuerySingleField<T> extends QueryField<T> {
//   QuerySingleField(String name) : super(name);
// }

abstract class ValueQuery<T> extends QueryField<T> {
  ValueQuery(String name) : super(name);
}

abstract class ArrayQuery<T> extends QueryField<T> {
  ArrayQuery(String name) : super(name);
}

class StringField extends ValueQuery<String> {
  StringField(String name) : super(name);

  @override
  Map<String, Object> compare(String string) {
    return {'stringValue': string};
  }
}

class IntegerField extends QueryField<int> {
  IntegerField(String name) : super(name);

  @override
  Map<String, String> compare(int integer) {
    return {'integerValue': integer.toString()};
  }
}

class DoubleField extends QueryField<double> {
  DoubleField(String name) : super(name);

  @override
  Map<String, double> compare(double float) {
    return {'doubleValue': float};
  }
}

class BoolField extends QueryField<bool> {
  BoolField(String name) : super(name);

  @override
  Map<String, bool> compare(bool boolean) {
    return {'booleanValue': boolean};
  }
}

class DateTimeField extends QueryField<DateTime> {
  DateTimeField(String name) : super(name);

  @override
  Map<String, String> compare(DateTime datetime) {
    return {'timestampValue': datetime.toIso8601String()};
  }
}

class ReferenceField extends QueryField<Reference> {
  ReferenceField(String name) : super(name);

  @override
  Map<String, String> compare(Reference reference) {
    return {'referenceValue': reference.toString()};
  }
}

typedef ValueMapper<T> = Map<String, Object> Function(T element);

class ArrayField<T> extends ArrayQuery<T> {
  final ValueMapper<T> _mapper;

  ArrayField(String name, this._mapper) : super(name);

  @override
  Map<String, Object> compare(T element) {
    return (_mapper(element));
  }
}
