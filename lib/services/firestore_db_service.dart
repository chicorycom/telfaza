import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:telfaza/services/auth_service.dart';
import 'package:telfaza/services/db_service.dart';

class FirestoreDBService extends DBService {
  final Firestore _firestore = Firestore.instance;
  final StorageReference _storage = FirebaseStorage.instance.ref();
  AuthService _auth;

  FirestoreDBService(AuthService auth) {
    _auth = auth;
  }

  Future<Stream<QuerySnapshot>> get outFavorites async {
    final user = await _getUserOrThrow();
    return _firestore
        .collection('favorites')
        .orderBy('added', descending: true)
        .where('user', isEqualTo: user.uid)
        .snapshots();
  }

  Future<Stream<QuerySnapshot>> get outLaters async {
    final user = await _getUserOrThrow();
    return _firestore
        .collection('laters')
        .orderBy('added', descending: true)
        .where('user', isEqualTo: user.uid)
        .snapshots();
  }

  Future<void> addFavorite(int id) async {
    final user = await _getUserOrThrow();
    final snap = await _firestore
        .collection('favorites')
        .where('movie', isEqualTo: id)
        .where('user', isEqualTo: user.uid)
        .getDocuments();
    if (snap.documents.length > 0) return;
    await _firestore.collection('favorites').add(
        {'user': user.uid, 'movie': id, 'added': FieldValue.serverTimestamp()});
  }

  Future<void> removeFavorite(int id) async {
    final user = await _getUserOrThrow();
    _firestore
        .collection('favorites')
        .where('movie', isEqualTo: id)
        .where('user', isEqualTo: user.uid)
        .getDocuments()
        .then((snapshot) {
      for (var doc in snapshot.documents) doc.reference.delete();
    });
  }

  Future<void> addLater(int id) async {
    final user = await _getUserOrThrow();
    final snap = await _firestore
        .collection('laters')
        .where('movie', isEqualTo: id)
        .where('user', isEqualTo: user.uid)
        .getDocuments();
    if (snap.documents.length > 0) return;
    await _firestore.collection('laters').add(
        {'user': user.uid, 'movie': id, 'added': FieldValue.serverTimestamp()});
  }

  Future<void> removeLater(int id) async {
    final user = await _getUserOrThrow();
    _firestore
        .collection('laters')
        .where('movie', isEqualTo: id)
        .where('user', isEqualTo: user.uid)
        .getDocuments()
        .then((snapshot) {
      for (var doc in snapshot.documents) doc.reference.delete();
    });
  }

  Future<User> _newUser(AuthUser authUser) async {
    await _firestore.collection('users').document(authUser.uid).setData({
      'email': authUser.email,
      'username': authUser.email.split('@')[0],
      'name': authUser.name,
      'photoUrl': authUser.photoUrl,
    });
    return User(
      uid: authUser.uid,
      email: authUser.email,
      username: authUser.email.split('@')[0],
      name: authUser.name,
      photoUrl: authUser.photoUrl,
    );
  }

  @override
  Future<User> currentUser() async {
    final authUser = await _auth.currentUser();

    if (authUser == null) return null;

    final documentSnapshot =
        await _firestore.collection('users').document(authUser.uid).get();

    final data = documentSnapshot.data;
    if (data == null) {
      return _newUser(authUser);
    }
    data['uid'] = documentSnapshot.documentID;
    return User.fromJSON(documentSnapshot.data);
  }

  Future<User> _getUserOrThrow() async {
    final user = await currentUser();

    if (user == null) {
      throw PlatformException(
        code: 'ERROR_MISSING_USER',
        message: 'Can\t retrieve current user',
      );
    }

    final uid = user.uid;

    if (uid == null) {
      throw PlatformException(
        code: 'ERROR_MISSING_UID',
        message: 'Can\t retrieve current user\'s uid',
      );
    }

    return user;
  }

  @override
  Future<void> updateProfile(Map<String, String> profile) async {
    final user = await _getUserOrThrow();
    final uid = user.uid;

    String username;
    if (profile.containsKey('username')) {
      username = profile['username'].toLowerCase();
      profile['username'] = username;
    }

    if (username != null && await usernameExists(username)) {
      throw PlatformException(
        code: 'ERROR_USERNAME_EXISTS',
        message: 'username already exists',
      );
    }

    final allowedFields = ['username', 'name'];
    for (var key in profile.keys) {
      if (!allowedFields.contains(key)) {
        throw PlatformException(
          code: 'ERROR_FIELD_NOT_ALLOWED',
          message: 'tried to update profile with a non allowed field',
        );
      }
    }

    return _firestore
        .collection('users')
        .document(uid)
        .setData(profile, merge: true);
  }

  Future<bool> usernameExists(String username) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .getDocuments();
    return result.documents.isNotEmpty;
  }

  @override
  Future<String> updatePhoto(File image) async {
    final user = await _getUserOrThrow();

    final ref = _storage.child(user.uid).child("profilePhoto");
    final uploadTask = ref.putFile(image);
    final url = await (await uploadTask.onComplete).ref.getDownloadURL();
    await _firestore
        .collection('users')
        .document(user.uid)
        .setData({'photoUrl': url}, merge: true);
    return url;
  }

  @override
  void dispose() {
    // TODO: implement dispose
  }
}
