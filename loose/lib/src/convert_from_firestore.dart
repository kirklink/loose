import 'package:loose/annotations.dart';
import 'package:loose/src/loose_exception.dart';


class FromFs {
  FromFs._();

  static String string(Map<String, Object> value, {bool allowNull = false}) {
    if (value.containsKey('stringValue')) {
      return value['stringValue'] as String;
    } else {
      return null;
    }
  }

  static int integer(Map<String, Object> value) {
    if (value.containsKey('integerValue')) {
      return int.parse(value['integerValue'] as String);
    } else {
      return null;
    }
  }

  static double float(Map<String, Object> value) {
    if (value.containsKey('doubleValue')) {
      return value['doubleValue'] as double;
    } else {
      return null;
    }
  }

  static bool boolean(Map<String, Object> value) {
    if (value.containsKey('booleanValue')) {
      return value['booleanValue'] as bool;
    } else {
      return null;
    }
  }

  static DateTime datetime(Map<String, Object> value) {
    if (value.containsKey('timestampValue')) {
      return DateTime.parse(value['timestampValue'] as String);
    } else {
      return null;
    }
  }

  static Reference reference(Map<String, Object> value) {
    if (value.containsKey('referenceValue')) {
      return Reference.fromFirestore(value);
    } else {
      return null;
    }
  }

  static List<T> list<T>(Map<String, Object> value, MapDecoder<T> mapDecoder) {
    if (value.containsKey('arrayValue')) {
      final valuesList = (value['arrayValue'] as Map<String, Object>)['values'] as List;
      return valuesList.map((e) => mapDecoder(e as Map<String, Object>)).toList();
    }
    return null;
  }

  static T map<T>(Map<String, Object> value, MapDecoder<T> mapDecoder) {
    if (value.containsKey('mapValue')) {
      final valueMap = (value['mapValue'] as Map<String, Object>)['fields'] as Map<String, Object>;
      print('VALUEMAP: $valueMap');
      return mapDecoder(valueMap);
    }
    return null;
    
  }


}

typedef MapDecoder<T> = T Function(Map<String, Object> value);