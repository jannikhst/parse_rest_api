import 'package:parse_rest_api/parse_rest_api.dart';

void main() async {
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
  //create reference object
  final docRef = doc.reference;
  //try to fetch document at given reference again
  doc = await docRef.fetch();
  //logout user, this revokes the current session and header
  await user.logout();
  try {
    //try to fetch document at given reference again
    doc = await docRef.fetch();
  } catch (parseError) {
    //prints object not found because object is not readable for public
    print(parseError);
  }
  //signIn again
  user = await Parse.signInUser('Pete', 'pete!1234');
  ////include new session token in header
  user.setTokenForParse();
  //allow public read & write requests
  acl.setPublic(true, true);
  //delete users rights
  acl.delete(user.id);
  //update the document with new access restrictions and content
  await docRef.update({
    'ACL': acl,
    'owner': null,
    'info': 'user deleted',
  });
  //logout user
  await user.logout();
  //delete user from server
  await user.delete();
  //create new batch object
  final batch = Parse.batch();
  //create todos
  var todos = <String>['Walk', 'Eat', 'Sleep', 'Swim'];
  //counter
  var x = 0;
  //iterate through todos
  for (var todo in todos) {
    //create new batch task
    batch.create('todos', {'name': todo, 'rank': ++x});
  }
  //new batch task: delete old document
  batch.delete(doc.collection, doc.id);
  //commits all batch tasks
  await batch.commit();
  //create new query object
  final query = CollectionReference('todos').query();
  //await returned documents
  final docs = await query
      //filter: where name is not 'Swim'
      .where('name', QueryFilter.notEqualTo('Swim'))
      //filter: where rank is greater than 1
      .where('rank', QueryFilter.greaterThanOrEqual(2))
      //order first by rank
      .orderBy('rank')
      //than order by name
      .orderBy('name')
      //return max 4 docs (default: 100)
      .limit(4)
      //get documents
      .get();
  //make sure there is no document containing 'Swim'
  assert(!docs.any((doc) => doc.data['name'] == 'Swim'));
  //decrement rank of first document of query result
  await docs.first.reference.update({'rank': ParseOperation.increment(-1)});
}
