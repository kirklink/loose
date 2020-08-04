import 'package:googleapis/firestore/v1.dart' as fs;

import 'package:loose/src/loose_exception.dart';
import 'package:loose/src/query/query_field.dart';
import 'package:loose/src/query/query_enums.dart';
import 'package:loose/src/query/query_enum_converters.dart';

abstract class BaseFilter {
  final String _op;
  BaseFilter(this._op);
  Map<String, Object> get result;
}

class CompositeFilter extends BaseFilter {

  CompositeFilter() : super('AND');
  
  final _filters = <BaseFilter>[];
  
  void addFilter(BaseFilter filter) {
    _filters.add(filter);
  }
  
  @override
  Map<String, Object> get result {
    return {
      'compositeFilter': {
        'op': super._op,
        'filters': _filters.map((e) => e.result).toList()
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

  final QueryField<T> _field;

  final _comparables = <fs.Value>[];
  
  bool _listOp = false;
  bool _unaryOp = false;
  
  Filter.field(this._field, FieldOp op, T comparable) : super(convertFieldOperator(op)) {
    _comparables.add(_field.compare(comparable));
  }

  Filter.unary(this._field, UnaryOp op) : super(convertUnaryOperator(op)) {
    _unaryOp = true;
  }
  

  Filter.list(this._field, ListOp op, List<T> comparables) : super(convertListOperator(op)) {
    if (comparables.length > 10) {
      throw LooseException('The comparables list cannot contain more than 10 elements.');
    }
    _listOp = true;
    _comparables.addAll(comparables.map((e) => _field.compare(e)).toList());
  }
    
  
  @override
  Map<String, Object> get result {    
    if (_unaryOp) {
      return {
      'unaryFilter': {
        'field': _field.result,
        'op': super._op
        }
      };
    } else if (_listOp) {
      // final array = fs.Value().arrayValue.values = _comparables;
      return {
        'fieldFilter': {
          'field': _field.result,
          'op': super._op,
          'value': {
            'arrayValue': {
              'values': _comparables.map((e) => e.toJson()).toList()
            }
          }
        }
      };
    } else {
      return {
        'fieldFilter': {
          'field': _field.result,
          'op': super._op,
          'value': _comparables[0].toJson()
        }
      };
    }

    
  }
}

// class Unary extends BaseFilter {
  
//   final QueryField _field;
  
//   Unary(this._field, UnaryOp op) : super (convertUnaryOperator(op));

//   @override
//   Map<String, Object> get result {
//     return {
//       'unaryFilter': {
//         'field': _field.result,
//         'op': super._op
//       }
//     };
//   }
// }
