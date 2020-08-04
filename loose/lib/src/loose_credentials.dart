import 'package:loose/src/loose_exception.dart';

class LooseCredentials {

  final String privateKeyId;
  final String privateKey;
  final String clientEmail;
  final String clientId;
  final String type;
  final bool fromApplicationDefault;

  
  LooseCredentials._([this.fromApplicationDefault = false, this.privateKeyId = '', this.privateKey = '', this.clientEmail = '', this.clientId = '', this.type = '']);

  factory LooseCredentials.fromServiceAccount(String privateKeyId, String privateKey, String clientEmail, String clientId, String type, [String name = '']) {
    if (name.isNotEmpty && _cache.containsKey(name)) {
      throw LooseException('Cached credentials with the name "$name" already exist.');
    }
    final creds = LooseCredentials._(false, privateKeyId, privateKey, clientEmail, clientId, type);
    if (name.isNotEmpty) {
      _cache[name] = creds;
    }
    return creds;
  }

  factory LooseCredentials.fromApplicationDefaultCredentials() {
    return LooseCredentials._(true);
  }

  factory LooseCredentials.fromCache(String name) {
    if (!_cache.containsKey(name)) {
      throw LooseException('Cached credentials with the name $name does not exist.');
    }
    return _cache[name];
  }

  static final _cache = <String, LooseCredentials>{};

  static String formatPrivateKey(String key) => key.replaceAll('\\n', '\u000A');


}