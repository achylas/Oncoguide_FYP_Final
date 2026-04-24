import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signUpDoctor({
    required String name,
    required String email,
    required String password,
  }) async {
    // 1. Create user in Firebase Auth
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    // 2. Store doctor data in Firestore
    await _firestore.collection('doctors').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'role': 'doctor',
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }
}
