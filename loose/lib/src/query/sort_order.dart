import '../document_field.dart';
import 'query_enums.dart';
import 'query_enum_converters.dart';

class SortOrder {
  final DocumentField _field;
  final SortDirection _direction;

  const SortOrder.asc(this._field) : _direction = SortDirection.asc;

  const SortOrder.dsc(this._field) : _direction = SortDirection.dsc;

  Map<String, Object> get encode =>
      {'field': _field.fieldPath, 'direction': convertDirection(_direction)};
}
