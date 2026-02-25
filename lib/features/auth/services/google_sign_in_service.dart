import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Initialize Google Sign-In
      await _googleSignIn.initialize();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount googleUser = await _googleSignIn
          .authenticate();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Create or update user document in Firestore
      await _createOrUpdateUserDocument(userCredential.user!);

      return userCredential;
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  static Future<void> _createOrUpdateUserDocument(User user) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    await userRef.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'photoURL': user.photoURL ?? '',
      'provider': 'google',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
