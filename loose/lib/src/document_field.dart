import 'reference.dart';

abstract class DocumentField<T> {
  final String name;
  DocumentField(this.name);
  Map<String, String> get fieldPath => {'fieldPath': name};
  Map<String, Object> comparison(T comparable);
}

abstract class ValueField<T> extends DocumentField<T> {
  ValueField(String name) : super(name);
}

// abstract class ArrayQuery<T> extends Field<T> {
//   ArrayQuery(String name) : super(name);
// }

class StringField extends ValueField<String> {
  StringField(String name) : super(name);

  @override
  Map<String, Object> comparison(String string) {
    return {'stringValue': string};
  }
}

class IntegerField extends ValueField<int> {
  IntegerField(String name) : super(name);

  @override
  Map<String, String> comparison(int integer) {
    return {'integerValue': integer.toString()};
  }
}

class DoubleField extends ValueField<double> {
  DoubleField(String name) : super(name);

  @override
  Map<String, double> comparison(double float) {
    return {'doubleValue': float};
  }
}

class BoolField extends ValueField<bool> {
  BoolField(String name) : super(name);

  @override
  Map<String, bool> comparison(bool boolean) {
    return {'booleanValue': boolean};
  }
}

class DateTimeField extends ValueField<DateTime> {
  DateTimeField(String name) : super(name);

  @override
  Map<String, String> comparison(DateTime datetime) {
    return {'timestampValue': datetime.toIso8601String()};
  }
}

class ReferenceField extends ValueField<Reference> {
  ReferenceField(String name) : super(name);

  @override
  Map<String, String> comparison(Reference reference) {
    return {'referenceValue': reference.toString()};
  }
}

typedef ValueMapper<T> = Map<String, Object> Function(T element);

class ArrayField<T> extends DocumentField<T> {
  final ValueMapper<T> _mapper;

  ArrayField(String name, this._mapper) : super(name);

  @override
  Map<String, Object> comparison(T element) {
    return (_mapper(element));
  }
}
