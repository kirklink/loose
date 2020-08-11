

import 'package:loose/annotations.dart';
import 'package:loose/src/loose_exception.dart';

class ToFs {

  ToFs._();

  static const _toNullValue = {'nullValue': 'NULL_VALUE'};

  static Map<String, Object> string(String string, {String defaultValue = '', bool useDefaultValue = false, bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    if (string != null) {
      return {'stringValue': string};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'stringValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  static Map<String, Object> integer(int integer, {int defaultValue = 0, bool useDefaultValue = false, bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    if (integer!= null) {
      return {'integerValue': integer.toString()};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'integerValue': defaultValue.toString()};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  static Map<String, Object> float(double float, {double defaultValue = 0.0, bool useDefaultValue = false, bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    if (float != null) {
      return {'doubleValue': float};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'doubleValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  static Map<String, Object> boolean(bool boolean, {bool defaultValue = false, bool useDefaultValue = false, bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    if (bool != null) {
      return {'booleanValue': boolean};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {'booleanValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  static Map<String, Object> datetime(DateTime datetime, {DateTime defaultValue, bool useDefaultValue = false, bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    if (datetime != null) {
      return {'timestampValue': datetime.toIso8601String()};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      defaultValue ??= DateTime(0);
      return {'timestampValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  static Map<String, Object> reference(Reference reference, {Reference defaultValue, bool useDefaultValue = false, bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    if (integer!= null) {
      return {'referenceValue': reference.toString()};
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      final def = defaultValue != null ? defaultValue.toString() : '';
      return {'referenceValue': def};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  static Map<String, Object> list(List<Map<String, Object>> values, {List<Map<String, Object>> defaultValue = const [], bool useDefaultValue = false, bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    if (values != null) {
      return {
        'arrayValue': {
          'values': values
        }
      };
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {
        'arrayValue': {
          'values': defaultValue
        }
      };
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  static Map<String, Object> map(Map<String, Object> fields, {Map<String, Object> defaultValue = const {}, bool useDefaultValue = false, bool allowNull = false}) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    if (fields != null) {
      return {
        'mapValue': {
          'fields': fields
        }
      };
    } else if (allowNull) {
      return _toNullValue;
    } else if (useDefaultValue) {
      return {
        'mapValue': {
          'fields': defaultValue
        }
      };
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

}