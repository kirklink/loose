import 'package:loose/annotations.dart';
import 'loose_exception.dart';

typedef MapDecoder<T> = T Function(Map<String, Object> value);

class FromFs {
  FromFs._();

  static String string(Object? value, {String defaultValue = ''}) {
    final o = value as Map<String, Object>;
    return o['stringValue'] as String? ?? defaultValue;
  }

  static String? stringNull(Object? value,
      {String name = '', bool allowNull = false}) {
    final o = value as Map<String, Object>;
    final v = o['stringValue'] as String?;
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static int integer(Object? value, {int defaultValue = 0}) {
    final o = value as Map<String, Object>;
    return int.tryParse(o['integerValue'] as String? ?? '') ?? defaultValue;
  }

  static int? integerNull(Object? value,
      {String name = '', bool allowNull = false}) {
    final o = value as Map<String, Object>;
    final v = int.tryParse(o['integerValue'] as String? ?? '');
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static double float(Object? value, {double defaultValue = 0.0}) {
    final o = value as Map<String, Object>;
    return o['doubleValue'] as double? ?? defaultValue;
  }

  static double? floatNull(Object? value,
      {String name = '', bool allowNull = false}) {
    final o = value as Map<String, Object>;
    final v = (o['doubleValue'] as num?)?.toDouble();
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static bool boolean(Object? value, {bool defaultValue = false}) {
    final o = value as Map<String, Object>;
    return o['booleanValue'] as bool? ?? defaultValue;
  }

  static bool? booleanNull(Object? value,
      {String name = '', bool allowNull = false}) {
    final o = value as Map<String, Object>;
    final v = o['booleanValue'] as bool?;
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static DateTime datetime(Object? value,
      {String defaultValue = '0000-01-01T00:00:00.000Z'}) {
    final o = value as Map<String, Object>;
    return DateTime.tryParse(o['timestampValue'] as String? ?? '') ??
        DateTime.parse(defaultValue);
  }

  static DateTime? datetimeNull(Object? value,
      {String name = '', bool allowNull = false}) {
    final o = value as Map<String, Object>;
    final v = DateTime.tryParse(o['timestampValue'] as String? ?? '');
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static Reference reference(Object? value, {String defaultValue = ''}) {
    final o = value as Map<String, Object>;
    return Reference.fromFirestore(o, defaultValue);
  }

  static Reference? referenceNull(Object? value,
      {String name = '', bool allowNull = false}) {
    final o = value as Map<String, Object>;
    final v = o['referenceValue'];
    if (v != null) {
      return Reference.fromFirestore(value);
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static List<T> list<T>(Object? value, MapDecoder<T> mapDecoder,
      {List<T> defaultValue = const []}) {
    final o = value as Map<String, Object>;
    final list = (o['arrayValue'] as Map<String, Object>)['values'] as List? ??
        defaultValue;
    return list.map((e) => mapDecoder(e as Map<String, Object>)).toList();
  }

  static List<T>? listNull<T>(Object? value, MapDecoder<T> mapDecoder,
      {String name = '', bool allowNull = false}) {
    final o = value as Map<String, Object>;
    if (o.containsKey('arrayValue')) {
      final valuesList =
          (o['arrayValue'] as Map<String, Object>)['values'] as List? ??
              const [];
      return valuesList
          .map((e) => mapDecoder(e as Map<String, Object>))
          .toList();
    } else if (allowNull) {
      return null;
    } else {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
  }

  static T map<T>(Object? value, MapDecoder<T> mapDecoder,
      {Map<String, Object> defaultValue = const {}}) {
    final o = value as Map<String, Object>;
    final valueMap = (o['mapValue'] as Map<String, Object>)['fields']
            as Map<String, Object>? ??
        const {};
    return mapDecoder(valueMap);
  }

  static T? mapNull<T>(Object? value, MapDecoder<T> mapDecoder,
      {String name = '', bool allowNull = false}) {
    final o = value as Map<String, Object>;
    final v = (o['mapValue'] as Map<String, Object>)['fields']
        as Map<String, Object>?;
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
