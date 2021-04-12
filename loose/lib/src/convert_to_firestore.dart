import 'package:loose/annotations.dart';
import 'loose_exception.dart';

class ToFs {
  ToFs._();

  static const _toNullValue = {'nullValue': 'NULL_VALUE'};

  static Map<String, Object> string(String string, String name,
      {String defaultValue = '',
      bool useDefaultValue = false,
      bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException(
          'Cannot allow null and use default value for "$name". Must only use one or neither.');
    }
    if (string != null) {
      return {'stringValue': string};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'stringValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed in "$name".');
    }
  }

  static Map<String, Object> integer(int integer, String name,
      {int defaultValue = 0,
      bool useDefaultValue = false,
      bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException(
          'Cannot allow null and use default value for "$name". Must only use one or neither.');
    }
    if (integer != null) {
      return {'integerValue': integer.toString()};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'integerValue': defaultValue.toString()};
    } else {
      throw LooseException('Null provided but not allowed in "$name".');
    }
  }

  static Map<String, Object> float(double float, String name,
      {double defaultValue = 0.0,
      bool useDefaultValue = false,
      bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException(
          'Cannot allow null and use default value for "$name". Must only use one or neither.');
    }
    if (float != null) {
      return {'doubleValue': float};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'doubleValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed in "$name".');
    }
  }

  static Map<String, Object> boolean(bool boolean, String name,
      {bool defaultValue = false,
      bool useDefaultValue = false,
      bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException(
          'Cannot allow null and use default value for "$name". Must only use one or neither.');
    }
    if (boolean != null) {
      return {'booleanValue': boolean};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'booleanValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed in "$name".');
    }
  }

  static Map<String, Object> datetime(DateTime datetime, String name,
      {String defaultValue = '0000-01-01T00:00:00.000Z',
      bool useDefaultValue = false,
      bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException(
          'Cannot allow null and use default value for "$name". Must only use one or neither.');
    }
    if (datetime != null) {
      return {'timestampValue': datetime.toUtc().toIso8601String()};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      final d = DateTime.parse(defaultValue);
      return {'timestampValue': d.toIso8601String()};
    } else {
      throw LooseException('Null provided but not allowed in "$name".');
    }
  }

  static Map<String, Object> reference(Reference reference, String name,
      {String defaultValue = '/',
      bool useDefaultValue = false,
      bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException(
          'Cannot allow null and use default value for "$name". Must only use one or neither.');
    }
    if (reference != null && reference.name.isNotEmpty) {
      return {'referenceValue': reference.name};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'referenceValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed in "$name".');
    }
  }

  static Map<String, Object> list(List<Map<String, Object>> values, String name,
      {List<Map<String, Object>> defaultValue = const [],
      bool useDefaultValue = false,
      bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException(
          'Cannot allow null and use default value for "$name". Must only use one or neither.');
    }
    if (values != null) {
      return {
        'arrayValue': {'values': values}
      };
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {
        'arrayValue': {'values': defaultValue}
      };
    } else {
      throw LooseException('Null provided but not allowed in "$name".');
    }
  }

  static Map<String, Object> map(Map<String, Object> fields, String name,
      {Map<String, Object> defaultValue = const {},
      bool useDefaultValue = false,
      bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException(
          'Cannot allow null and use default value for "$name". Must only use one or neither.');
    }
    if (fields != null) {
      return {
        'mapValue': {'fields': fields}
      };
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {
        'mapValue': {'fields': defaultValue}
      };
    } else {
      throw LooseException('Null provided but not allowed in "$name".');
    }
  }
}
