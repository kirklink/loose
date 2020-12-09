import 'package:loose/annotations.dart';
import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/query/query_field.dart';
import 'package:loose/src/query/query_enums.dart';
import 'package:loose/src/query/query_enum_converters.dart';
import 'package:loose/src/reference.dart';

abstract class BaseFilter {
  Map<String, Object> encode();
}

abstract class FieldFilter implements BaseFilter {}

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

// class FilterResult {
//   final Encoder _encoder;
//   final String _op;
//   final List<Map<String, Object>> _comparables;
//   final Map<String, String> _fieldPath;

//   FilterResult(this._fieldPath, this._op, this._encoder,
//       [this._comparables = const []]);

//   Map<String, Object> encode() {
//     if (_encoder is FieldFilterEncoder) {
//       return _encoder.encode(_fieldPath, _op, _comparables);
//     } else if (_encoder is UnaryFilterEncoder) {
//       return _encoder.encode(_fieldPath, _op, const []);
//     } else if (_encoder is ArrayFilterEncoder) {
//       return _encoder.encode(_fieldPath, _op, _comparables);
//     } else {
//       throw LooseException('A valid Encoder must be provided.');
//     }
//   }
// }

class ValueFilter<T> implements FieldFilter {
  final ValueQuery<T> _field;
  var _op = '';
  final _comparables = <Map<String, Object>>[];
  Encoder _encoder;

  ValueFilter(this._field);

  @override
  Map<String, Object> encode() {
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

class CompositeFilter implements BaseFilter {
  final List<BaseFilter> _filters;

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

class Filter {
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
