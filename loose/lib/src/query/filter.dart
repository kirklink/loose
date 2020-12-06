import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/query/query_field.dart';
import 'package:loose/src/query/query_enums.dart';
import 'package:loose/src/query/query_enum_converters.dart';
import 'package:loose/src/reference.dart';

abstract class BaseFilter {
  final String _op;
  BaseFilter(this._op);
  Map<String, Object> get encode;
}

class CompositeFilter extends BaseFilter {
  CompositeFilter() : super('AND');

  final _filters = <BaseFilter>[];

  void addFilter(BaseFilter filter) {
    _filters.add(filter);
  }

  @override
  Map<String, Object> get encode {
    return {
      'compositeFilter': {
        'op': super._op,
        'filters': _filters.map((e) => e.encode).toList()
      }
    };
  }
}

// Aggregate filter
// class DerivedFilter extends Filter {
// final _derivedFilters = [FieldOperator.max, FieldOperator.min];
//   max
//   min
//   etc
// }

class Filter<T> extends BaseFilter {
  QueryField<T> _field;

  final _comparables = <Map<String, Object>>[];

  bool _listOp = false;
  bool _unaryOp = false;

  Filter.stringField(StringField field, FieldOp op, String comparable)
      : super(convertFieldOperator(op)) {
    _comparables.add(field.compare(comparable));
  }

  Filter.integerField(IntegerField field, FieldOp op, int comparable)
      : super(convertFieldOperator(op)) {
    _comparables.add(field.compare(comparable));
  }

  Filter.doubleField(DoubleField field, FieldOp op, double comparable)
      : super(convertFieldOperator(op)) {
    _comparables.add(field.compare(comparable));
  }

  Filter.boolField(BoolField field, FieldOp op, bool comparable)
      : super(convertFieldOperator(op)) {
    _comparables.add(field.compare(comparable));
  }

  Filter.dateTimeField(DateTimeField field, FieldOp op, DateTime comparable)
      : super(convertFieldOperator(op)) {
    _comparables.add(field.compare(comparable));
  }

  Filter.referenceField(ReferenceField field, FieldOp op, Reference comparable)
      : super(convertFieldOperator(op)) {
    _comparables.add(field.compare(comparable));
  }

  Filter.arrayContains(ArrayField<T> field, T comparable)
      : super(convertFieldOperator(FieldOp.listContains)) {
    _comparables.add(field.compare(comparable));
  }

  Filter.isIn(QueryField<T> field, List<T> comparables)
      : super(convertListOperator(ListOp.isIn)) {
    if (comparables.length > 10) {
      throw LooseException(
          'The comparables list cannot contain more than 10 elements.');
    }
    _listOp = true;
    _comparables.addAll(comparables.map((e) => _field.compare(e)).toList());
  }

  Filter.isNotIn(QueryField<T> field, List<T> comparables)
      : super(convertListOperator(ListOp.isNotIn)) {
    if (comparables.length > 10) {
      throw LooseException(
          'The comparables list cannot contain more than 10 elements.');
    }
    _listOp = true;
    _comparables.addAll(comparables.map((e) => _field.compare(e)).toList());
  }

  Filter.arrayContainsAnyOf(QueryField<T> field, List<T> comparables)
      : super(convertListOperator(ListOp.listContainsAny)) {
    if (comparables.length > 10) {
      throw LooseException(
          'The comparables list cannot contain more than 10 elements.');
    }
    _listOp = true;
    _comparables.addAll(comparables.map((e) => _field.compare(e)).toList());
  }

  Filter.isNull(QueryField field)
      : super(convertUnaryOperator(UnaryOp.isNull)) {
    _unaryOp = true;
  }

  Filter.isNaN(QueryField field) : super(convertUnaryOperator(UnaryOp.isNaN)) {
    _unaryOp = true;
  }

  // Filter.unary(this._field, UnaryOp op) : super(convertUnaryOperator(op)) {
  //   _unaryOp = true;
  // }

  Filter.list(this._field, ListOp op, List<T> comparables)
      : super(convertListOperator(op)) {
    if (comparables.length > 10) {
      throw LooseException(
          'The comparables list cannot contain more than 10 elements.');
    }
    _listOp = true;
    _comparables.addAll(comparables.map((e) => _field.compare(e)).toList());
  }

  @override
  Map<String, Object> get encode {
    if (_unaryOp) {
      return {
        'unaryFilter': {'field': _field.result, 'op': super._op}
      };
    } else if (_listOp) {
      // final array = fs.Value().arrayValue.values = _comparables;
      return {
        'fieldFilter': {
          'field': _field.result,
          'op': super._op,
          'value': {
            'arrayValue': {'values': _comparables}
          }
        }
      };
    } else {
      return {
        'fieldFilter': {
          'field': _field.result,
          'op': super._op,
          'value': _comparables[0]
        }
      };
    }
  }
}
