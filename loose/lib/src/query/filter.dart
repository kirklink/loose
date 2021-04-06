import '../document_field.dart';
import 'query_enums.dart';
import 'query_enum_converters.dart';

abstract class Filter<T> {
  Map<String, Object> encode();

  static ValueFilterBuilder<T> value<T>(ValueField<T> field) {
    return ValueFilterBuilder(field);
  }

  static ArrayFilterBuilder<T> array<T>(ArrayField<T> field) {
    return ArrayFilterBuilder(field);
  }

  static CompositeFilter composite(List<Filter> filters) {
    return CompositeFilter(filters);
  }

  static const empty = EmptyFilter._();
}

class EmptyFilter implements Filter {
  const EmptyFilter._();
  @override
  Map<String, Object> encode() => const {};
}

class FieldFilter<T> implements Filter {
  final DocumentField<T> _field;
  final FieldOp _op;
  final T _comparable;

  const FieldFilter(this._field, this._op, this._comparable);

  @override
  Map<String, Object> encode() {
    return {
      'fieldFilter': {
        'field': _field.fieldPath,
        'op': convertFieldOperator(_op),
        'value': _field.comparison(_comparable)
      }
    };
  }
}

class UnaryFilter implements Filter {
  final DocumentField _field;
  final UnaryOp _op;

  const UnaryFilter(this._field, this._op);

  @override
  Map<String, Object> encode() {
    return {
      'unaryFilter': {
        'field': _field.fieldPath,
        'op': convertUnaryOperator(_op)
      }
    };
  }
}

class ArrayFilter<T> implements Filter {
  final DocumentField<T> _field;
  final ListOp _op;
  final List<T> _comparables;

  const ArrayFilter(this._field, this._op, this._comparables);

  @override
  Map<String, Object> encode() {
    return {
      'fieldFilter': {
        'field': _field.fieldPath,
        'op': _op,
        'value': {
          'arrayValue': {
            'values': _comparables.map((e) => _field.comparison(e)).toList()
          }
        }
      }
    };
  }
}

class ValueFilterBuilder<T> {
  final ValueField<T> _field;

  const ValueFilterBuilder(this._field);

  FieldFilter equals(T comparable) {
    return FieldFilter(_field, FieldOp.equal, comparable);
  }

  FieldFilter doesNotEqual(T comparable) {
    return FieldFilter(_field, FieldOp.notEqual, comparable);
  }

  FieldFilter isLessThan(T comparable) {
    return FieldFilter(_field, FieldOp.lessThan, comparable);
  }

  FieldFilter isLessThanOrEquals(T comparable) {
    return FieldFilter(_field, FieldOp.lessThanOrEqual, comparable);
  }

  FieldFilter isGreaterThan(T comparable) {
    return FieldFilter(_field, FieldOp.greaterThan, comparable);
  }

  FieldFilter isGreaterThanOrEquals(T comparable) {
    return FieldFilter(_field, FieldOp.equal, comparable);
  }

  UnaryFilter isNaN() {
    return UnaryFilter(_field, UnaryOp.isNaN);
  }

  UnaryFilter isNull() {
    return UnaryFilter(_field, UnaryOp.isNull);
  }

  ArrayFilter isIn(List<T> comparables) {
    return ArrayFilter(_field, ListOp.isIn, comparables);
  }

  ArrayFilter isNotIn(List<T> comparables) {
    return ArrayFilter(_field, ListOp.isNotIn, comparables);
  }
}

class ArrayFilterBuilder<T> {
  final ArrayField<T> _field;

  const ArrayFilterBuilder(this._field);

  FieldFilter contains(T comparable) {
    return FieldFilter(_field, FieldOp.listContains, comparable);
  }

  ArrayFilter containsAnyOf(List<T> comparables) {
    return ArrayFilter(_field, ListOp.listContainsAny, comparables);
  }
}

class CompositeFilter implements Filter {
  final List<Filter> _filters;

  const CompositeFilter(this._filters);

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
