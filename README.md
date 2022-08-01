## Native Dart Parse API Client

A CloudFirestore inspired Client for Parse REST API. Explore more features in the example file.

## ACL and User

Create document and user and save it to parse with access restrictions:

```dart
import 'package:parse_rest_api/parse_rest_api.dart';

  //Initialize Parse
  Parse.initialize('https://MY.URL/parse', 'MY-APP-ID');
  //Create collection reference
  final myclass = CollectionReference('myclass');
  //register new user
  var user = await Parse.registerUser('Pete', 'pete!1234');
  //include current session token in header
  user.setTokenForParse();
  //create new acl object
  final acl = ParseACL();
  //deny public read & write requests
  acl.setPublic(false, false);
  //allow only user to read and write
  acl.addRights(user.id, true, true);
  //create document inside collection with the defined access restriction
  var doc = await myclass.add({
    'owner': 'Pete',
    'ACL': acl,
  });
```

## Query collections

Create a query document and return result:

```dart
//create new query
  final query = CollectionReference('todos').query();
  //await returned documents
  final docs = await query
      //filter: where name is not 'Swim'
      .where('name', QueryFilter.notEqualTo('Swim'))
      //filter: where rank is greater than 1
      .where('rank', QueryFilter.greaterThanOrEqual(2))
      //order first by rank
      .orderBy('rank')
      //then order by name
      .orderBy('name')
      //return max 4 docs (default: 100)
      .limit(4)
      //get documents
      .get();
```

