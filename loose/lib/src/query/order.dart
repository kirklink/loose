import 'query_field.dart';
import 'query_enums.dart';
import 'query_enum_converters.dart';

class Order {
  final QueryField _field;
  Direction _direction;

  // Order(this._field, this._direction);

  Order.asc(this._field) {
    _direction = Direction.asc;
  }

  Order.dsc(this._field) {
    _direction = Direction.dsc;
  }

  Map<String, Object> get encode =>
      {'field': _field.fieldPath, 'direction': convertDirection(_direction)};
}
