import 'case.dart';

enum NullMode { useDefaultValues, allowNull, throwOnNull }

class LooseDatetime {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;
  final int millisecond;
  const LooseDatetime(this.year,
      {this.month = 0,
      this.day = 0,
      this.hour = 0,
      this.minute = 0,
      this.second = 0,
      this.millisecond = 0});
}

/// The annotation to convert a Dart class into a Firebase document.
///
/// [name]: rename the Firestore document to correspond with a database table name.
/// [useCase]: automatically convert the table name and field names to another case, unless
/// the field is annotated explicitly with a 'name' parameter.
/// [readOnly]: Throws a LooseException if tried to write to the database.
class LooseDocument {
  final Case useCase;
  final NullMode readMode;
  final NullMode saveMode;
  final bool suppressWarnings;
  const LooseDocument({
    this.useCase = Case.none,
    this.readMode = NullMode.useDefaultValues,
    this.saveMode = NullMode.useDefaultValues,
    // this.readonlyNulls = false,
    this.suppressWarnings = false,
  });
}

/// The annotation to enhance a Dart class property into a Firebase document field.
///
/// [LooseField] is not required and only necessary if additional annotations are required
/// on the field. Otherwise, Dart class properties of a [LooseField] are automatically converted
/// to fields.
///
/// [name]: sets an explict name on a field to correspond with a database field name.
/// [readOnly]: will read this field from the database but not write it to the database. Useful
/// for things like id's or timestamps.
/// [ignore]: will ignore this field completely; it will not be in the table fields.
class LooseField {
  final String name;
  final bool readOnly;
  final bool ignore;
  final NullMode readMode;
  final NullMode saveMode;
  final bool canQuery;
  final bool ignoreIfNested;
  final bool ignoreInLists;
  final String privateFieldGetter;
  final Object defaultValue;
  const LooseField(
      {this.name = '',
      this.readOnly = false,
      this.ignore = false,
      this.saveMode,
      this.readMode,
      this.canQuery = true,
      this.defaultValue,
      this.ignoreIfNested = false,
      this.ignoreInLists = false,
      this.privateFieldGetter = ''});
}

class LooseMap {
  final NullMode readMode;
  final NullMode saveMode;
  final bool suppressWarnings;

  const LooseMap(
      {this.readMode = NullMode.useDefaultValues,
      this.saveMode = NullMode.useDefaultValues,
      this.suppressWarnings = false});
}
