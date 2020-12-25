// @dart=2.8
import 'dart:convert';
import 'dart:async';
import 'parse_base.dart';
import 'package:http/http.dart' as http;

class ParseACL {
  final Map<String, Map<String, bool>> _acl = {};

  ///Add [read] or [write] rights for specific user-[id]
  void addRights(String id, bool read, bool write) {
    _acl.update(
      id,
      (map) {
        map['write'] = write;
        map['read'] = read;
        return map;
      },
      ifAbsent: () => {'read': read, 'write': write},
    );
  }

  ///Delete all rights from user-[id]
  void delete(String id) => _acl.removeWhere((key, value) => key == id);

  ///Check whether user with [id] has read access
  bool canRead(String id) => _acl[id]['read'] ?? false;

  ///Check whether user with [id] has write access
  bool canWrite(String id) => _acl[id]['write'] ?? false;

  ///Define public [read] and [write] access
  void setPublic(bool read, bool write) => addRights('*', read, write);

  ///simply put ACL object in data map from document to push
  ///this method will be called automatically
  Map<String, dynamic> toJson() => _acl;

  ///returns a string containing all ids that have restrictions or rights
  @override
  String toString() => 'ACL${_acl.keys.toList()}';
  static ParseACL fromMap(Map<String, dynamic> data) {
    final acl = ParseACL();
    if (data == null) return acl;
    for (var key in data.keys) {
      acl.addRights(key, data['read'], data['write']);
    }
    return acl;
  }
}

class _BatchTask {
  final String method, path;
  final Map<String, dynamic> data;
  _BatchTask(this.method, this.path, this.data);
}

class _ParseBatch {
  final headers, url;
  bool _commited;
  List<_BatchTask> _tasks;
  _ParseBatch(this.headers, this.url) {
    _commited = false;
    _tasks = [];
  }

  /// Create a new batch task which updates the document in [collection] with [id] using the provided [data] map
  /// Dont forget to commit your batch in order to push your changes
  void update(String collection, String id, Map<String, dynamic> data) =>
      _tasks.add(_BatchTask('PUT', '/parse/classes/$collection/$id', data));

  /// Create a new batch task which deletes the document in [collection] with [id]
  /// Dont forget to commit your batch in order to push your changes
  void delete(String collection, String id) =>
      _tasks.add(_BatchTask('DELETE', '/parse/classes/$collection/$id', null));

  /// Create a new batch task which creates a document in [collection] using the provided [data] map
  /// Dont forget to commit your batch in order to push your changes
  void create(String collection, Map<String, dynamic> data) =>
      _tasks.add(_BatchTask('POST', '/parse/classes/$collection', data));

  ///commits all inserted tasks
  ///returns [true] if every single task was successful, else returns [false]
  Future<bool> commit() async {
    if (_commited) throw UnsupportedError('Batch was already committed');
    final response = await http.post('$url/parse/batch',
        headers: headers, body: jsonEncode(_convert()));
    if (response.statusCode != 200) {
      throw UnsupportedError(
          '\nStatusCode: ${response.statusCode}\nMessage: ${jsonDecode(response.body)}');
    }
    List result = jsonDecode(response.body);
    return result.every((map) => map.containsKey('success'));
  }

  Map<String, dynamic> _convert() {
    final requests = _tasks
        .map<Map<String, dynamic>>((task) => {
              'method': task.method,
              'path': task.path,
              'body': task.data,
            })
        .toList();
    return {'requests': requests};
  }
}

class ParseQuery {
  int _limit, _skip;
  String _collection;
  List<String> _orderBy;
  Map<String, dynamic> _content;
  ParseQuery(String collection) {
    _content ??= {};
    _orderBy ??= [];
    _collection = collection;
  }

  ///returns only documents which pass all [filter]s
  ///chaining is allowed
  ///EXAMPLE: where().where().orderBy().get();
  ParseQuery where(String field, QueryFilter filter) {
    if (filter.key == null) {
      _content.putIfAbsent(field, () => filter.value);
    } else {
      _content.putIfAbsent(field, () => {});
      _content[field].putIfAbsent(filter.key, () => filter.value);
    }
    return this;
  }

  ///returns documents sorted by [field] in the desired order
  ///chaining is allowed
  ///EXAMPLE: where().orderBy().orderBy().get();
  ParseQuery orderBy(String field, {bool ascending = true}) {
    var order = ascending ? '' : '-';
    _orderBy.add('$order$field');
    return this;
  }

  ///returns maximal [limit] documents
  ///IMPORTANT: The default limit is 100 documents per API call
  ///chaining will be ignored
  ///EXAMPLE: orderBy().limit(10).limit(1000).get();
  ///=> returns list of maximal 1000 documents
  ParseQuery limit(int limit) {
    _limit = limit;
    return this;
  }

  ///skips the first [skip] documents
  ///IMPORTANT: The default skip-value is 0 documents
  ///chaining will be ignored
  ///EXAMPLE: orderBy().skip(2).skip(25).get();
  ///=> returns without the first 25 documents
  ParseQuery skip(int skip) {
    _skip = skip;
    return this;
  }

  String get _buffer {
    final sb = StringBuffer();
    if (_content.isNotEmpty) sb.write('where=${jsonEncode(_content)}');
    if (_skip != null) sb.write('${sb.isEmpty ? '' : '&'}skip=$_skip');
    if (_limit != null) sb.write('${sb.isEmpty ? '' : '&'}limit=$_limit');
    if (_orderBy.isNotEmpty) {
      sb.write(
          '${sb.isEmpty ? '' : '&'}order=${_orderBy.toString().replaceAll('[', '').replaceAll(']', '')}');
    }
    return sb.toString();
  }

  ///returns a Future containing the query result
  ///EXAMPLE: where().skip(25).limit(50).get();
  Future<List<ParseDocument>> get() async {
    final content = Uri.encodeFull(_buffer);
    var response = await http.get(
        '${Parse._url}/parse/classes/$_collection?$content',
        headers: Parse._headers);
    Parse._errorHandler(response);
    Map<String, dynamic> result = jsonDecode(response.body);
    List docs = result['results'];
    return docs
        .map<ParseDocument>(
            (e) => ParseDocument(jsonEncode(e), true, null, _collection))
        .toList();
  }
}

abstract class Parse {
  static String _url = '';
  static String _appId = 'JanniksFirstParse';
  static Map<String, String> _headers = {};

  ///sets the [url], [appID] and additional headers for api calls
  static void initialize(String url, String appID,
      {Map<String, String> headers}) {
    _url = url;
    _appId = appID;
    _headers = {
      'X-Parse-Application-Id': _appId,
      'Content-Type': 'application/json',
    };
    for (var key in headers.keys) {
      _headers.putIfAbsent(key, () => headers[key]);
    }
  }

  ///returns a new Parse Batch
  static _ParseBatch batch() => _ParseBatch(_headers, _url);

  static void _errorHandler(http.Response response) {
    Map<String, dynamic> resp = jsonDecode(response.body);
    if (resp.containsKey('error') &&
        resp.containsKey('code') &&
        (response.statusCode != 201 && response.statusCode != 200)) {
      throw UnsupportedError(
          '\nStatusCode: ${response.statusCode}\nMessage: ${jsonDecode(response.body)}');
    }
  }

  ///returns a new query in the given [collection]
  static ParseQuery query(String collection) => ParseQuery(collection);

  ///updates the document in [collection] with [id] and the provided [data]
  ///throws [UnsupportedError] if user has no access rights or document ist does not exist
  static Future<ParseDocResponse> update(
      String collection, String id, Map<String, dynamic> data) async {
    var response = await http.put('$_url/parse/classes/$collection/$id',
        headers: _headers, body: jsonEncode(data));
    final success = response.statusCode == 200;
    _errorHandler(response);
    return ParseDocResponse(
        success,
        DocReference(collection, id),
        success
            ? DateTime.parse(jsonDecode(response.body)['updatedAt'])
            : null);
  }

  ///deletes the document in [collection] with [id]
  ///throws [UnsupportedError] if user has no access rights or document ist does not exist
  static Future<ParseDocResponse> delete(String collection, String id) async {
    var response = await http.delete('$_url/parse/classes/$collection/$id',
        headers: _headers);
    _errorHandler(response);
    return ParseDocResponse(response.statusCode == 200,
        DocReference(collection, id), DateTime.now());
  }

  ///creates a new document in [collection] with [id] containing the provided data
  static Future<ParseDocument> create(
      String collection, Map<String, dynamic> data) async {
    print(jsonEncode(data));
    final response = await http.post('$_url/parse/classes/$collection',
        headers: _headers, body: jsonEncode(data));
    _errorHandler(response);
    return ParseDocument(
        response.body, response.statusCode == 201, data, collection);
  }

  ///returns the document in [collection] with [id]
  ///throws [UnsupportedError] if user has no access rights or document ist does not exist
  static Future<ParseDocument> fetch(String collection, String id) async {
    var response = await http.get('$_url/parse/classes/$collection/$id',
        headers: _headers);
    _errorHandler(response);
    return ParseDocument(
        response.body, response.statusCode == 200, null, collection);
  }

  ///creates and returns new user with [username], [password] and the optional additional [data]
  ///- unique username and email is enforced
  ///- password is stored savly and will be never exposed
  static Future<ParseUser> registerUser(String username, String password,
      {Map<String, dynamic> data}) async {
    // ignore: omit_local_variable_types
    Map<String, dynamic> push = data ?? {};
    // ignore: omit_local_variable_types
    final Map<String, String> tmpHead = {}
      ..addAll(_headers)
      ..['X-Parse-Revocable-Session'] = '1';
    push['username'] = username;
    push['password'] = password;
    var response = await http.post('$_url/parse/users',
        headers: tmpHead, body: jsonEncode(push));
    _errorHandler(response);
    return ParseUser._fromResponse(response);
  }

  ///sign in an returns existing user with [username] and [password]
  static Future<ParseUser> signInUser(String username, String password) async {
    // ignore: omit_local_variable_types
    final Map<String, String> tmpHead = {}
      ..addAll(_headers)
      ..['X-Parse-Revocable-Session'] = '1';
    final content = Uri.encodeFull('username=$username&password=$password');
    var response =
        await http.get('$_url/parse/login?$content', headers: tmpHead);
    _errorHandler(response);
    return ParseUser._fromResponse(response);
  }

  ///validates and returns user if session [token] is valid
  ///else returns [null]
  static Future<ParseUser> validateSession(String token) async {
    // ignore: omit_local_variable_types
    final Map<String, String> tmpHead = {}
      ..addAll(_headers)
      ..['X-Parse-Session-Token'] = token;
    var response = await http.get('$_url/parse/users/me', headers: tmpHead);
    if (response.statusCode == 200) {
      return ParseUser._fromResponse(response);
    } else {
      return null;
    }
  }

  ///updates user with [id] if [token] is valid using the provided [data]
  static Future<ParseUserResponse> updateUser(
      String id, String token, Map<String, dynamic> data) async {
    // ignore: omit_local_variable_types
    final Map<String, String> tmpHead = {}
      ..addAll(_headers)
      ..['X-Parse-Session-Token'] = token;
    var response = await http.put('$_url/parse/users/$id',
        body: jsonEncode(data), headers: tmpHead);
    _errorHandler(response);
    return ParseUserResponse(response.statusCode == 200,
        DateTime.parse(jsonDecode(response.body)['updatedAt']));
  }

  ///deletes user with [id] if provided session [token] is valid
  static Future<ParseUserResponse> deleteUser(String id, String token) async {
    // ignore: omit_local_variable_types
    final Map<String, String> tmpHead = {}
      ..addAll(_headers)
      ..['X-Parse-Session-Token'] = token;
    var response = await http.delete('$_url/parse/users/$id', headers: tmpHead);
    _errorHandler(response);
    return ParseUserResponse(response.statusCode == 200, DateTime.now());
  }

  ///sign in as anonymous user
  ///provide random [id] to create new user
  ///its not possible to sign in again as this specific user after session token is revoked
  static Future<ParseUser> anonUser(String id) async {
    // ignore: omit_local_variable_types
    final Map<String, String> tmpHead = {}
      ..addAll(_headers)
      ..['X-Parse-Revocable-Session'] = '1';
    var response = await http.post('$_url/parse/users',
        headers: tmpHead,
        body: jsonEncode({
          'authData': {
            'anonymous': {'id': id.toLowerCase()}
          }
        }));
    _errorHandler(response);
    return ParseUser._fromResponse(response);
  }

  ///includes the provided [token] for future api calls in the http header
  ///Use this to gain access to restricted documents
  ///token will be automatically removed after logout or revoking session
  static void setCurrentUserToken(String token) =>
      _headers['X-Parse-Session-Token'] = token;

  ///revoke the session by providing the session [token]
  ///Use this to logout an user
  static Future<void> revokeSession(String token) async {
    // ignore: omit_local_variable_types
    final Map<String, String> tmpHead = {}
      ..addAll(_headers)
      ..['X-Parse-Session-Token'] = token;
    _headers.removeWhere((key, value) => key == 'X-Parse-Session-Token');
    var response = await http.post('$_url/parse/logout', headers: tmpHead);
    _errorHandler(response);
  }
}

class ParseUserResponse {
  final bool isChanged;
  final DateTime updatedAt;
  ParseUserResponse(this.isChanged, this.updatedAt);
}

class ParseUser {
  final DateTime createdAt, updatedAt;
  final String id, token;
  final Map<String, dynamic> data;
  ParseUser(this.id, this.token, this.createdAt, this.updatedAt, this.data);

  static ParseUser _fromResponse(http.Response response) {
    Map<String, dynamic> data = jsonDecode(response.body);
    // ignore: omit_local_variable_types
    DateTime ca = DateTime.parse(data['createdAt']),
        cu = data.containsKey('updatedAt')
            ? DateTime.parse(data['updatedAt'])
            : ca;
    String id = data['objectId'], token = data['sessionToken'];
    data.removeWhere((key, value) =>
        ['updatedAt', 'createdAt', 'objectId', 'sessionToken'].contains(key));
    return ParseUser(id, token, ca, cu, data);
  }

  ///revokes the current session token
  Future<void> logout() async => await Parse.revokeSession(token);

  ///updates the user [data]
  Future<ParseUserResponse> update(Map<String, dynamic> data) async =>
      await Parse.updateUser(id, token, data);

  ///deletes this user
  Future<ParseUserResponse> delete() async => await Parse.deleteUser(id, token);
  void setTokenForParse() => Parse.setCurrentUserToken(token);
}
