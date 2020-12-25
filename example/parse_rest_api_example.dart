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
    //print object not found because object is not readable for public
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
}
