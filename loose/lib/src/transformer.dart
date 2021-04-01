import 'query/query_field.dart';

abstract class Transformer {
  Map<String, Object> transform();

  factory Transformer.increment(IntegerField field, [int by = 1]) {
    return IncrementTransform(field, by);
  }

  factory Transformer.decrement(IntegerField field, [int by = 1]) {
    return DecrementTransform(field, by);
  }

  factory Transformer.add(DoubleField field, num number) {
    return AddTransform(field, number);
  }

  factory Transformer.subtract(DoubleField field, num number) {
    return SubtractTransform(field, number);
  }

  factory Transformer.max(DoubleField field, num number) {
    return MaxTransform(field, number);
  }

  factory Transformer.min(DoubleField field, num number) {
    return MinTransform(field, number);
  }

  factory Transformer.timestamp(DateTimeField field) {
    return ServerTimestampTransform(field);
  }
}

class IncrementTransform implements Transformer {
  final IntegerField _field;
  final int _by;

  IncrementTransform(this._field, this._by);
  @override
  Map<String, Object> transform() {
    final r = <String, Object>{
      'increment': {'integerValue': _by.toString()}
    }..addAll(_field.fieldPath);
    return r;
  }
}

class DecrementTransform implements Transformer {
  final IntegerField _field;
  final int _by;

  DecrementTransform(this._field, this._by);
  @override
  Map<String, Object> transform() {
    final r = <String, Object>{
      'increment': {'integerValue': (_by * -1).toString()}
    }..addAll(_field.fieldPath);
    return r;
  }
}

class AddTransform implements Transformer {
  final DoubleField _field;
  final num _number;

  AddTransform(this._field, this._number);
  @override
  Map<String, Object> transform() {
    final r = <String, Object>{
      'increment': {'doubleValue': _number}
    }..addAll(_field.fieldPath);
    return r;
  }
}

class SubtractTransform implements Transformer {
  final DoubleField _field;
  final num _number;

  SubtractTransform(this._field, this._number);
  @override
  Map<String, Object> transform() {
    final r = <String, Object>{
      'increment': {'doubleValue': (_number * -1)}
    }..addAll(_field.fieldPath);
    return r;
  }
}

class MaxTransform implements Transformer {
  final DoubleField _field;
  final num _number;

  MaxTransform(this._field, this._number);
  @override
  Map<String, Object> transform() {
    final r = <String, Object>{
      'maximum': {'doubleValue': _number}
    }..addAll(_field.fieldPath);
    return r;
  }
}

class MinTransform implements Transformer {
  final DoubleField _field;
  final num _number;

  MinTransform(this._field, this._number);
  @override
  Map<String, Object> transform() {
    final r = <String, Object>{
      'minimum': {'doubleValue': _number}
    }..addAll(_field.fieldPath);
    return r;
  }
}

class ServerTimestampTransform implements Transformer {
  final DateTimeField _field;
  ServerTimestampTransform(this._field);
  @override
  Map<String, Object> transform() {
    final r = <String, Object>{'setToServerValue': 'REQUEST_TIME'}
      ..addAll(_field.fieldPath);
    return r;
  }
}

class FieldTransformHandler {
  FieldTransformHandler();

  IncrementTransform increment(IntegerField field, [int by = 1]) {
    return IncrementTransform(field, by);
  }

  DecrementTransform decrement(IntegerField field, [int by = 1]) {
    return DecrementTransform(field, by);
  }

  AddTransform add(DoubleField field, num number) {
    return AddTransform(field, number);
  }

  SubtractTransform subtract(DoubleField field, num number) {
    return SubtractTransform(field, number);
  }

  MaxTransform max(DoubleField field, num number) {
    return MaxTransform(field, number);
  }

  MinTransform min(DoubleField field, num number) {
    return MinTransform(field, number);
  }

  ServerTimestampTransform timestamp(DateTimeField field) {
    return ServerTimestampTransform(field);
  }
}
