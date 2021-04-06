import 'case.dart';
import 'document.dart';

/// The annotation to convert a Dart class into a Firebase document.
///
/// [name]: rename the Firestore document to correspond with a database table name.
/// [useCase]: automatically convert the table name and field names to another case, unless
/// the field is annotated explicitly with a 'name' parameter.
/// [readOnly]: Throws a LooseException if tried to write to the database.
class LooseDocument {
  final Case useCase;
  // final Document document;
  final bool allowNulls;
  final bool useDefaultValues;
  final bool readonlyNulls;
  final bool suppressWarnings;
  const LooseDocument({
    this.useCase = Case.none,
    this.allowNulls = false,
    this.useDefaultValues = true,
    this.readonlyNulls = false,
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
  final bool allowNull;
  final bool canQuery;
  final bool useDefaultValue;
  final bool readonlyNull;
  final bool ignoreIfNested;
  final bool ignoreInLists;
  final String privateFieldGetter;
  const LooseField(
      {this.name = '',
      this.readOnly = false,
      this.ignore = false,
      this.allowNull,
      this.canQuery = true,
      this.useDefaultValue = true,
      this.readonlyNull = false,
      this.ignoreIfNested = false,
      this.ignoreInLists = false,
      this.privateFieldGetter = ''});
}

class LooseMap {
  final bool allowNulls;
  final bool useDefaultValues;
  final bool readonlyNulls;
  final bool suppressWarnings;

  const LooseMap(
      {this.allowNulls = false,
      this.useDefaultValues = false,
      this.readonlyNulls = false,
      this.suppressWarnings = false});
}

// class LooseReference {
//   const LooseReference();
// }
