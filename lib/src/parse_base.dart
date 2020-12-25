// @dart=2.8
import 'dart:convert';

import 'parse.dart';

class _PQFEqual extends QueryFilter {
  _PQFEqual(dynamic value) : super(null, value);
}

class _PQFLessThan extends QueryFilter {
  _PQFLessThan(double value) : super('\$lt', value);
}

class _PQFLessThanOrEqual extends QueryFilter {
  _PQFLessThanOrEqual(double value) : super('\$lte', value);
}

class _PQFGreaterThan extends QueryFilter {
  _PQFGreaterThan(double value) : super('\$gt', value);
}

class _PQFGreaterThanOrEqual extends QueryFilter {
  _PQFGreaterThanOrEqual(double value) : super('\$gte', value);
}

class _PQFNotEqualTo extends QueryFilter {
  _PQFNotEqualTo(dynamic value) : super('\$ne', value);
}

class _PQFContainedIn extends QueryFilter {
  _PQFContainedIn(List value) : super('\$in', value);
}

class _PQFNotContainedIn extends QueryFilter {
  _PQFNotContainedIn(List value) : super('\$nin', value);
}

class _PQFExists extends QueryFilter {
  _PQFExists(bool value) : super('\$exists', value);
}

class _PQFContainsAll extends QueryFilter {
  _PQFContainsAll(List value) : super('\$all', value);
}

class _PQFRegex extends QueryFilter {
  _PQFRegex(RegExp value) : super('\$regex', value);
}

class _PQFText extends QueryFilter {
  _PQFText(String value) : super('\$text', value);
}

abstract class QueryFilter {
  final String key;
  final dynamic value;
  QueryFilter(this.key, this.value);

  ///only values lower than [value]
  static _PQFLessThan lessThan(double value) => _PQFLessThan(value);

  ///only values lower or equal than [value]
  static _PQFLessThanOrEqual lessThanOrEqual(double value) =>
      _PQFLessThanOrEqual(value);

  ///only values greater than [value]
  static _PQFGreaterThan greaterThan(double value) => _PQFGreaterThan(value);

  ///only values greater or equal than [value]
  static _PQFGreaterThanOrEqual greaterThanOrEqual(double value) =>
      _PQFGreaterThanOrEqual(value);

  ///only values that are not equal to [value]
  static _PQFNotEqualTo notEqualTo(dynamic value) => _PQFNotEqualTo(value);

  ///only arrays which contains at least one of the given [values]
  static _PQFContainedIn containedIn(List values) => _PQFContainedIn(values);

  ///only arrays which contains none of the given [values]
  static _PQFNotContainedIn notContainedIn(List values) =>
      _PQFNotContainedIn(values);

  ///the field is null or not null ([value])
  static _PQFExists exists(bool value) => _PQFExists(value);

  ///Contains all of the given values
  static _PQFContainsAll containsAll(List values) => _PQFContainsAll(values);

  ///Requires that a key’s value match a regular expression
  static _PQFRegex regex(RegExp regex) => _PQFRegex(regex);

  ///Performs a full text search on indexed fields
  static _PQFText text(String text) => _PQFText(text);

  ///only values that are equal to [value]
  static _PQFEqual equals(dynamic value) => _PQFEqual(value);

  ///this method will be called automatically
  Map<String, dynamic> toJson() => {key: value};

  ///returns the object in parse-expression formatted string
  @override
  String toString() {
    return '"$key":$value';
  }
}

class ParseOperation {
  ///increments the value at the given field (+ / -)
  static Map<String, dynamic> increment(int value) =>
      {'__op': 'Increment', 'amount': value};

  ///appends the given array of objects to the end of an array field.
  static Map<String, dynamic> arrayAddAny(List objects) =>
      {'__op': 'Add', 'objects': objects};

  ///adds only the given objects which aren’t already contained in an array field to that field.
  ///The position of the insert is not guaranteed.
  static Map<String, dynamic> arrayAddNew(List objects) =>
      {'__op': 'AddUnique', 'objects': objects};

  ///removes all instances of each given object from an array field.
  static Map<String, dynamic> arrayRemove(List objects) =>
      {'__op': 'Remove', 'objects': objects};

  ///Deletes single field of object
  static Map<String, dynamic> deleteThis() => {'__op': 'Delete'};
}

class ParseDocument {
  String _id, _collection;
  DateTime _createdAt, _updatedAt;
  bool _exists;
  Map<String, dynamic> _data;
  DocReference _reference;
  ParseACL _acl;

  ParseDocument(
      String body, bool exists, Map<String, dynamic> input, String collection) {
    //Check if document exists
    _exists = exists;
    if (!_exists) return;
    //Convert response body in parameters
    Map<String, dynamic> data = jsonDecode(body);
    _createdAt = DateTime.parse(data['createdAt']);
    //checking whether document was ever updated
    _updatedAt = data.containsKey('updatedAt')
        ? DateTime.parse(data['updatedAt'])
        : _createdAt;
    _acl = ParseACL.fromMap(data['ACL']);
    _id = data['objectId'] as String;
    //Remove already converted keys from map
    if (input == null) {
      //Document was fetched
      _data = data;
      _data.removeWhere((key, v) =>
          ['objectId', 'updatedAt', 'createdAt', 'ACL'].contains(key));
    } else {
      //Document was created (using original data)
      _data = input;
    }
    //setting collection (class)
    _collection = collection;
    _reference = DocReference(collection, id);
  }
  ParseACL get ACL => _acl;
  String get id => _id;
  String get collection => _collection;
  bool get exists => _exists;
  DocReference get reference => _reference;
  DateTime get createdAt => _createdAt;
  DateTime get updatedAt => _updatedAt;
  Map<String, dynamic> get data => _data;
  @override
  String toString() {
    return '$collection/$id => $data | acl: $ACL, ca: $createdAt, ua: $updatedAt';
  }
}

class ParseDocResponse {
  final bool isChanged;
  final DocReference reference;
  final DateTime updatedAt;
  ParseDocResponse(this.isChanged, this.reference, this.updatedAt);
}

class CollectionReference {
  final String collection;
  CollectionReference(this.collection);

  ///add a document to the collection with provided [data]
  Future<ParseDocument> add(Map<String, dynamic> data) async =>
      await Parse.create(collection, data);

  ///fetch the document with [id] in this collection
  Future<ParseDocument> fetch(String id) async =>
      await Parse.fetch(collection, id);

  ///update document with [id] using the provided [data]
  Future<ParseDocResponse> update(String id, Map<String, dynamic> data) async =>
      await Parse.update(collection, id, data);

  ///creates a document reference with the provided [id]
  DocReference doc(String id) => DocReference(collection, id);

  ///creates a query object in this collection
  ParseQuery query() => ParseQuery(collection);

  ///returns up to 10.000 Documents
  Future<List<ParseDocument>> getDocs() async =>
      await Parse.query(collection).limit(10000).get();
}

class DocReference {
  final String id, collection;
  CollectionReference _ref;
  DocReference(this.collection, this.id) {
    _ref = CollectionReference(collection);
  }

  CollectionReference get collectionRef => _ref;

  ///updates this document with the provided [data]
  Future<ParseDocResponse> update(Map<String, dynamic> data) async =>
      await Parse.update(collection, id, data);

  ///fetch the document from server
  Future<ParseDocument> fetch() async => await Parse.fetch(collection, id);

  ///deletes this document
  Future<ParseDocResponse> delete() async => await Parse.delete(collection, id);
}
