import 'package:loose/src/query/query_field.dart';
import 'package:loose/src/query/query_enums.dart';
import 'package:loose/src/query/query_enum_converters.dart';


class Order {
  final QueryField _field;
  final Direction _direction;
  const Order(this._field, this._direction);

  Map<String, Object> get product => {
    'field': _field.result,
    'direction': convertDirection(_direction)
  };
}
