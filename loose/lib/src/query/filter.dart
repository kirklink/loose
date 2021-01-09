import '../loose_exception.dart';
import 'query_field.dart';
import 'query_enums.dart';
import 'query_enum_converters.dart';

// abstract class BaseFilter {
//   Map<String, Object> encode();
// }

abstract class FieldFilter implements Filter {}

// Aggregate filter
// class DerivedFilter extends Filter {
// final _derivedFilters = [FieldOperator.max, FieldOperator.min];
//   max
//   min
//   etc
// }
abstract class Encoder {
  Map<String, Object> encode(Map<String, String> fieldPath, String op,
      List<Map<String, Object>> comparables);
}

class FieldFilterEncoder implements Encoder {
  @override
  Map<String, Object> encode(Map<String, String> fieldPath, String op,
      List<Map<String, Object>> comparables) {
    return {
      'fieldFilter': {'field': fieldPath, 'op': op, 'value': comparables[0]}
    };
  }
}

class UnaryFilterEncoder implements Encoder {
  @override
  Map<String, Object> encode(Map<String, String> fieldPath, String op,
      List<Map<String, Object>> comparables) {
    return {
      'unaryFilter': {'field': fieldPath, 'op': op}
    };
  }
}

class ArrayFilterEncoder implements Encoder {
  @override
  Map<String, Object> encode(Map<String, String> fieldPath, String op,
      List<Map<String, Object>> comparables) {
    return {
      'fieldFilter': {
        'field': fieldPath,
        'op': op,
        'value': {
          'arrayValue': {'values': comparables}
        }
      }
    };
  }
}

class ValueFilter<T> implements FieldFilter {
  final ValueQuery<T> _field;
  var _op = '';
  final _comparables = <Map<String, Object>>[];
  Encoder _encoder;

  ValueFilter(this._field);

  @override
  Map<String, Object> encode() {
    if (_encoder == null) {
      throw LooseException(
          'Cannot encode a filter until the comparison is set.');
    }
    return _encoder.encode(_field.fieldPath, _op, _comparables);
  }

  ValueFilter<T> compare(FieldOp op, T comparable) {
    _op = convertFieldOperator(op);
    _comparables.add(_field.compare(comparable));
    _encoder = FieldFilterEncoder();
    return this;
    // return FilterResult(
    //     _field.fieldPath, _op, FieldFilterEncoder(), _comparables);
  }

  ValueFilter<T> equals(T comparable) {
    return compare(FieldOp.equal, comparable);
  }

  ValueFilter<T> doesNotEqual(T comparable) {
    return compare(FieldOp.notEqual, comparable);
  }

  ValueFilter<T> isLessThan(T comparable) {
    return compare(FieldOp.lessThan, comparable);
  }

  ValueFilter<T> isLessThanOrEquals(T comparable) {
    return compare(FieldOp.lessThanOrEqual, comparable);
  }

  ValueFilter<T> isGreaterThan(T comparable) {
    return compare(FieldOp.greaterThan, comparable);
  }

  ValueFilter<T> isGreaterThanOrEquals(T comparable) {
    return compare(FieldOp.equal, comparable);
  }

  ValueFilter<T> isNaN() {
    _op = convertUnaryOperator(UnaryOp.isNaN);
    _encoder = UnaryFilterEncoder();
    return this;
    // return FilterResult(
    //     _field.fieldPath, _op, UnaryFilterEncoder(), _comparables);
  }

  ValueFilter<T> isNull() {
    _op = convertUnaryOperator(UnaryOp.isNull);
    _encoder = UnaryFilterEncoder();
    return this;
    // return FilterResult(
    //     _field.fieldPath, _op, UnaryFilterEncoder(), _comparables);
  }

  ValueFilter<T> isIn(List<T> comparables) {
    _op = convertListOperator(ListOp.isIn);
    _comparables.addAll(comparables.map((e) => _field.compare(e)).toList());
    _encoder = ArrayFilterEncoder();
    return this;
    // return FilterResult(
    //     _field.fieldPath, _op, ArrayFilterEncoder(), _comparables);
  }

  ValueFilter<T> isNotIn(List<T> comparables) {
    _op = convertListOperator(ListOp.isNotIn);
    _comparables.addAll(comparables.map((e) => _field.compare(e)).toList());
    _encoder = ArrayFilterEncoder();
    return this;
    // return FilterResult(
    //     _field.fieldPath, _op, ArrayFilterEncoder(), _comparables);
  }
}

class ArrayFilter<T> implements FieldFilter {
  final ArrayQuery<T> _field;
  var _op = '';
  final _comparables = <Map<String, Object>>[];
  Encoder _encoder;

  ArrayFilter(this._field);

  @override
  Map<String, Object> encode() {
    if (_encoder == null) {
      throw LooseException('Cannot encode a filter until the operator is set.');
    }
    return _encoder.encode(_field.fieldPath, _op, _comparables);
  }

  ArrayFilter<T> contains(T comparable) {
    _op = convertFieldOperator(FieldOp.listContains);
    _comparables.add(_field.compare(comparable));
    _encoder = FieldFilterEncoder();
    return this;
    // return FilterResult(
    //     _field.fieldPath, _op, FieldFilterEncoder(), _comparables);
  }

  ArrayFilter<T> containsAnyOf(List<T> comparables) {
    _op = convertListOperator(ListOp.listContainsAny);
    _comparables.addAll(comparables.map((e) => _field.compare(e)).toList());
    _encoder = ArrayFilterEncoder();
    return this;
    // return FilterResult(
    //     _field.fieldPath, _op, ArrayFilterEncoder(), _comparables);
  }
}

class CompositeFilter implements Filter {
  final List<FieldFilter> _filters;

  CompositeFilter(this._filters);

  @override
  Map<String, Object> encode() {
    return {
      'compositeFilter': {
        'op': 'AND',
        'filters': _filters.map((e) => e.encode()).toList()
      }
    };
  }
}

abstract class Filter {
  Map<String, Object> encode();

  static ValueFilter<T> value<T>(ValueQuery<T> field) {
    return ValueFilter(field);
  }

  static ArrayFilter<T> array<T>(ArrayField<T> field) {
    return ArrayFilter(field);
  }

  static CompositeFilter composite(List<FieldFilter> filters) {
    return CompositeFilter(filters);
  }
}
