
import 'constants.dart';

abstract class Resource {
  Resource? get parent;
  String get id;
  String get path;


}

// resource or its children should validate an idPath and return a clean path
// instead of each caller

// example from WriteUpdate

// bool _request.document.pathIsGood(idPath)

// final tokenCount =
//         dynamicNameToken.allMatches(_request.document.path).length;
// return tokenCount != idPath.length

// String _request.document.mergedPath(idPath)
// _workingPath = '${_request.document.path}';

//     for (final id in _idPath) {
//       _workingPath = _workingPath.replaceFirst(dynamicNameToken, id);
//     }
//   return workingPath;

// or
// String _request.document.mergedPath // '' means error, couldn't be merged

//                                     // null means error, couldn't be merged
//                                     //
