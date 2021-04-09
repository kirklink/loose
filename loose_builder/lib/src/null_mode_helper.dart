import 'package:source_gen/source_gen.dart';

int getNullMode(ConstantReader reader, String fieldName) {
  var mode = reader
          .peek(fieldName)
          ?.objectValue
          ?.getField('useDefaultValues')
          ?.toIntValue() ??
      0;
  mode = reader
          .peek(fieldName)
          ?.objectValue
          ?.getField('allowNull')
          ?.toIntValue() ??
      mode;
  mode = reader
          .peek(fieldName)
          ?.objectValue
          ?.getField('throwOnNull')
          ?.toIntValue() ??
      mode;
  return mode;
}
