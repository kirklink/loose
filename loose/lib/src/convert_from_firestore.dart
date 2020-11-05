import 'package:loose/annotations.dart';
import 'package:loose/src/loose_exception.dart';

class FromFs {
  FromFs._();

  static String string(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    if (value == null && allowNull) {
      return null;
    } else if (value == null && !allowNull) {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
    if (value.containsKey('stringValue')) {
      return value['stringValue'] as String;
    } else {
      return null;
    }
  }

  static int integer(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    if (value == null && allowNull) {
      return null;
    } else if (value == null && !allowNull) {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
    if (value.containsKey('integerValue')) {
      return int.parse(value['integerValue'] as String);
    } else {
      return null;
    }
  }

  static double float(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    if (value == null && allowNull) {
      return null;
    } else if (value == null && !allowNull) {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num).toDouble();
    } else {
      return null;
    }
  }

  static bool boolean(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    if (value == null && allowNull) {
      return null;
    } else if (value == null && !allowNull) {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
    if (value.containsKey('booleanValue')) {
      return value['booleanValue'] as bool;
    } else {
      return null;
    }
  }

  static DateTime datetime(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    if (value == null && allowNull) {
      return null;
    } else if (value == null && !allowNull) {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
    if (value.containsKey('timestampValue')) {
      return DateTime.parse(value['timestampValue'] as String);
    } else {
      return null;
    }
  }

  static Reference reference(Map<String, Object> value,
      {String name = '', bool allowNull = false}) {
    if (value == null && allowNull) {
      return null;
    } else if (value == null && !allowNull) {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
    if (value.containsKey('referenceValue')) {
      return Reference.fromFirestore(value);
    } else {
      return null;
    }
  }

  static List<T> list<T>(Map<String, Object> value, MapDecoder<T> mapDecoder,
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
          (value['arrayValue'] as Map<String, Object>)['values'] as List;
      return valuesList
          .map((e) => mapDecoder(e as Map<String, Object>))
          .toList();
    }
    return null;
  }

  static T map<T>(Map<String, Object> value, MapDecoder<T> mapDecoder,
      {String name = '', bool allowNull = false}) {
    if (value == null && allowNull) {
      return null;
    } else if (value == null && !allowNull) {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
    if (value.containsKey('mapValue')) {
      final valueMap = (value['mapValue'] as Map<String, Object>)['fields']
          as Map<String, Object>;
      return mapDecoder(valueMap);
    }
    return null;
  }
}

typedef MapDecoder<T> = T Function(Map<String, Object> value);
