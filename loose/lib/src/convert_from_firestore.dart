import 'package:loose/annotations.dart';
import 'loose_exception.dart';

typedef MapDecoder<T> = T Function(Map<String, Object> value);

class FromFs {
  FromFs._();

  static String string(Map<String, Object> value, {String defaultValue = ''}) {
    return value['stringValue'] as String ?? defaultValue;
  }

  static String stringNull(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    final v = value['stringValue'] as String;
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static int integer(Map<String, Object> value, {int defaultValue = 0}) {
    return int.tryParse(value['integerValue'] as String ?? '') ?? defaultValue;
  }

  static int integerNull(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    final v = int.tryParse(value['integerValue'] as String ?? '');
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static double float(Map<String, Object> value, {double defaultValue = 0.0}) {
    return value['doubleValue'] as double ?? defaultValue;
  }

  static double floatNull(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    final v = (value['doubleValue'] as num).toDouble();
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static bool boolean(Map<String, Object> value, {bool defaultValue = false}) {
    return value['booleanValue'] as bool ?? defaultValue;
  }

  static bool booleanNull(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    final v = value['booleanValue'] as bool;
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static DateTime datetime(Map<String, Object> value,
      {String defaultValue = '0000-01-01T00:00:00.000Z'}) {
    return DateTime.tryParse(value['timestampValue'] as String ?? '') ??
        DateTime.parse(defaultValue);
  }

  static DateTime datetimeNull(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    final v = DateTime.tryParse(value['timestampValue'] as String ?? '');
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static Reference reference(Map<String, Object> value,
      {String defaultValue = '/'}) {
    return Reference.fromFirestore(value, defaultValue);
  }

  static Reference referenceNull(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    final v = value['referenceValue'];
    if (v != null) {
      return Reference.fromFirestore(value);
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static List<T> list<T>(Map<String, Object> value, MapDecoder<T> mapDecoder,
      {List<T> defaultValue = const []}) {
    final list =
        (value['arrayValue'] as Map<String, Object>)['values'] as List ??
            defaultValue;
    return list.map((e) => mapDecoder(e as Map<String, Object>)).toList();
  }

  static List<T> listNull<T>(
      Map<String, Object> value, MapDecoder<T> mapDecoder,
      {String name = '', bool allowNull = false}) {
    if (value == null && allowNull) {
      return null;
    } else if (value == null && !allowNull) {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
    if (value.containsKey('arrayValue')) {
      final valuesList =
          (value['arrayValue'] as Map<String, Object>)['values'] as List ??
              const [];
      return valuesList
          .map((e) => mapDecoder(e as Map<String, Object>))
          .toList();
    }
    return null;
  }

  static T map<T>(Map<String, Object> value, MapDecoder<T> mapDecoder,
      {Map<String, Object> defaultValue = const {}}) {
    final valueMap = (value['mapValue'] as Map<String, Object>)['fields']
        as Map<String, Object>;
    return mapDecoder(valueMap);
  }

  static T mapNull<T>(Map<String, Object> value, MapDecoder<T> mapDecoder,
      {String name = '', bool allowNull = false}) {
    final v = (value['mapValue'] as Map<String, Object>)['fields']
        as Map<String, Object>;
    if (v != null) {
      return mapDecoder(v);
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }
}
