import 'package:loose/src/case.dart';
import 'package:loose/src/document.dart';

/// The annotation to convert a Dart class into a Firebase document.
///
/// [name]: rename the Firestore document to correspond with a database table name.
/// [useCase]: automatically convert the table name and field names to another case, unless
/// the field is annotated explicitly with a 'name' parameter.
/// [readOnly]: Throws a LooseException if tried to write to the database.
class LooseDocument {
  final Case useCase;
  final Document document;
  final bool allowNull;
  final bool useDefaultValues;
  const LooseDocument(this.document, {
    this.useCase = Case.none,
    this.allowNull = false,
    this.useDefaultValues = false
  });
}

// /// The annotation to convert a Dart class into a Firebase document.
// ///
// /// [name]: rename the Firestore document to correspond with a database table name.
// /// [useCase]: automatically convert the table name and field names to another case, unless
// /// the field is annotated explicitly with a 'name' parameter.
// /// [readOnly]: Throws a LooseException if tried to write to the database.
// class LooseCollection {
//   final Resource heritage;
//   const LooseCollection(this.heritage);
// }


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
  final bool readNulls;
  const LooseField({this.name = '', this.readOnly = false, this.ignore = false, this.allowNull, this.canQuery = false, this.useDefaultValue, this.readNulls});
}


class LooseMap {
  const LooseMap();
}

// class LooseReference {
//   const LooseReference();
// }