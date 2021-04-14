import 'package:loose/annotations.dart';
import 'loose_exception.dart';

typedef MapDecoder<T> = T Function(Map<String, dynamic> value);

class FromFs {
  FromFs._();

  static String string(dynamic? value, {String defaultValue = ''}) {
    final o = value['stringValue'] as String?;
    return o ?? defaultValue;
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

  static int integer(dynamic? value, {int defaultValue = 0}) {
    final o = value['integerValue'] as String?;
    return int.tryParse(o ?? '') ?? defaultValue;
  }

  static int? integerNull(dynamic? value,
      {String name = '', bool allowNull = false}) {
    final o = value['integerValue'] as String?;
    final v = int.tryParse(o ?? '');
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static double float(dynamic? value, {double defaultValue = 0.0}) {
    final o = value['doubleValue'] as double?;
    return o ?? defaultValue;
  }

  static double? floatNull(dynamic? value,
      {String name = '', bool allowNull = false}) {
    final o = value['doubleValue'] as double?;
    final v = o?.toDouble();
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static bool boolean(dynamic? value, {bool defaultValue = false}) {
    final o = value['booleanValue'] as bool?;
    return o ?? defaultValue;
  }

  static bool? booleanNull(dynamic? value,
      {String name = '', bool allowNull = false}) {
    final v = value['booleanValue'] as bool?;
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static DateTime datetime(dynamic? value,
      {String defaultValue = '0001-01-01T00:00:00.000Z'}) {
    final o = value['timestampValue'] as String?;
    return DateTime.tryParse(o ?? '') ?? DateTime.parse(defaultValue);
  }

  static DateTime? datetimeNull(dynamic? value,
      {String name = '', bool allowNull = false}) {
    final o = value['timestampValue'] as String?;
    final v = DateTime.tryParse(o ?? '');
    if (v != null) {
      return v;
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static Reference reference(dynamic? value, {String defaultValue = ''}) {
    return Reference.fromFirestore(value, defaultValue);
  }

  static Reference? referenceNull(dynamic? value,
      {String name = '', bool allowNull = false}) {
    final v = value['referenceValue'] as String?;
    if (v != null) {
      return Reference.fromFirestore(value);
    } else if (allowNull) {
      return null;
    } else {
      throw LooseException(
          'Null not allowed in "$name". Use "readNull" annotation to allow.');
    }
  }

  static List<T> list<T>(dynamic? value, MapDecoder<T> mapDecoder,
      {List<T> defaultValue = const []}) {
    final o = value['arrayValue']?['values'] as List?;
    final list = o ?? defaultValue;
    return list.map((e) => mapDecoder(e as Map<String, dynamic>)).toList();
  }

  static List<T>? listNull<T>(dynamic? value, MapDecoder<T> mapDecoder,
      {String name = '', bool allowNull = false}) {
    final o = value?['arrayValue']?['values'] as List?;
    if (o != null) {
      return o.map((e) => mapDecoder(e as Map<String, Object>)).toList();
    } else if (allowNull) {
      return null;
    } else {
      final knownField = 'in field "$name" ';
      throw LooseException(
          'A null value was read ${knownField}but nulls are not allowed. Use either "allowNull" or "readNull" annotation to allow.');
    }
  }

  static T map<T>(dynamic? value, MapDecoder<T> mapDecoder,
      {Map<String, Object> defaultValue = const {}}) {
    // final o = value as Map<String, Object>;
    final o = value?['mapValue']?['fields'] as Map<String, dynamic>?;
    return mapDecoder(o ?? const {});
  }

  static T? mapNull<T>(dynamic? value, MapDecoder<T> mapDecoder,
      {String name = '', bool allowNull = false}) {
    final v = value?['mapValue']?['fields'] as Map<String, dynamic>?;
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
