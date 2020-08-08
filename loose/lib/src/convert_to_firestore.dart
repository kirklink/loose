

import 'package:loose/src/loose_exception.dart';

class ToFirestore {

  final toNullValue = {'nullValue': 'NULL_VALUE'};
  
  bool _useDefaultValue = false;
  bool _allowNull = false;
  ToFirestore([bool useDefaultValue = false, bool allowNull = false]) {
    if (useDefaultValue && allowNull) {
      throw LooseException('Cannot allow null and use default value. Must only use one or neither.');
    }
    _useDefaultValue = useDefaultValue;
    _allowNull = allowNull;
  }

  Map<String, Object> string(String string, [String defaultValue = '']) {
    if (string != null) {
      return {'stringValue': string};
    } else if (_allowNull) {
      return toNullValue;
    } else if (_useDefaultValue) {
      return {'stringValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  Map<String, Object> integer(int integer, [int defaultValue = 0]) {
    if (integer!= null) {
      return {'integerValue': integer as String};
    } else if (_allowNull) {
      return toNullValue;
    } else if (_useDefaultValue) {
      return {'integerValue': defaultValue as String};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  Map<String, Object> float(double float, [double defaultValue = 0.0]) {
    if (float != null) {
      return {'doubleValue': float};
    } else if (_allowNull) {
      return toNullValue;
    } else if (_useDefaultValue) {
      return {'doubleValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  Map<String, Object> boolean(bool boolean, [bool defaultValue = false]) {
    if (bool != null) {
      return {'booleanValue': boolean};
    } else if (_allowNull) {
      return toNullValue;
    } else if (_useDefaultValue) {
      return {'booleanValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  Map<String, Object> dateTime(DateTime datetime, [String defaultValue = '0000-01-01T00:00:00.000Z']) {
    if (datetime != null) {
      return {'timestampValue': datetime.toIso8601String()};
    } else if (_allowNull) {
      return toNullValue;
    } else if (_useDefaultValue) {
      return {'timestampValue': defaultValue};
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  Map<String, Object> list(List<Map<String, Object>> values, [List<Map<String, Object>> defaultValue = const []]) {
    if (values != null) {
      return {
        'arrayValue': {
          'values': values
        }
      };
    } else if (_allowNull) {
      return toNullValue;
    } else if (_useDefaultValue) {
      return {
        'arrayValue': {
          'values': defaultValue
        }
      };
    } else {
      throw LooseException('Null provided but not allowed.');
    }
  }

  Map<String, Object> map(Map<String, Object> fields, [Map<String, Object> defaultValue = const {}]) {
    if (fields != null) {
      return {
        'mapValue': {
          'fields': fields
        }
      };
    } else if (_allowNull) {
      return toNullValue;
    } else if (_useDefaultValue) {
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