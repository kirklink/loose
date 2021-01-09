import 'query_enums.dart';

String convertFieldOperator(FieldOp op) {
  switch (op) {
    case FieldOp.equal:
      return 'EQUAL';
      break;
    case FieldOp.notEqual:
      return 'NOT_EQUAL';
      break;
    case FieldOp.lessThan:
      return 'LESS_THAN';
      break;
    case FieldOp.lessThanOrEqual:
      return 'LESS_THAN_OR_EQUAL';
      break;
    case FieldOp.greaterThan:
      return 'GREATER_THAN';
      break;
    case FieldOp.greaterThanOrEqual:
      return 'GREATER_THAN_OR_EQUAL';
      break;
    case FieldOp.listContains:
      return 'ARRAY_CONTAINS';
      break;
    default:
      return 'NONE';
      break;
  }
}

String convertListOperator(ListOp op) {
  switch (op) {
    case ListOp.isIn:
      return 'IN';
      break;
    case ListOp.isNotIn:
      return 'NOT_IN';
      break;
    case ListOp.listContainsAny:
      return 'ARRAY_CONTAINS_ANY';
      break;
    default:
      return 'NONE';
      break;
  }
}

String convertUnaryOperator(UnaryOp op) {
  switch (op) {
    case UnaryOp.isNaN:
      return 'IS_NAN';
      break;
    case UnaryOp.isNull:
      return 'IS_NULL';
      break;
    default:
      return 'NONE';
      break;
  }
}

String convertDirection(Direction direction) {
  switch (direction) {
    case Direction.asc:
      return 'ASCENDING';
      break;
    case Direction.dsc:
      return 'DESCENDING';
      break;
    default:
      return 'ASCENDING';
  }
}
