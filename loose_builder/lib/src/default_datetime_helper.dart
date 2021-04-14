import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import 'loose_builder_exception.dart';

DateTime dateTimeConverter(ConstantReader reader) {
  DateTime d;
  final m = 'Default value for DateTime must be a LooseDatetime';
  try {
    final o = reader.objectValue;

    if (o.type.toString() != 'LooseDatetime') {
      throw LooseBuilderException(m);
    }
    final now = o.getField('now')!.toBoolValue() ?? false;
    if (now) {
      d = DateTime.utc(0);
    } else {
      final year = o.getField('year')!.toIntValue()!;
      if (year < 1) {
        final m = 'Minimum year value is 1.';
        throw LooseBuilderException(m);
      }
      final month = o.getField('month')!.toIntValue()!;
      final day = o.getField('day')!.toIntValue()!;
      final hour = o.getField('hour')!.toIntValue()!;
      final min = o.getField('minute')!.toIntValue()!;
      final sec = o.getField('second')!.toIntValue()!;
      final msec = o.getField('millisecond')!.toIntValue()!;

      d = DateTime.utc(year, month, day, hour, min, sec, msec);
    }
  } catch (_) {
    throw LooseBuilderException(m);
  }
  return d;
}
