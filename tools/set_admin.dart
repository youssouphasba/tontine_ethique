import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';

/// Utility to set Admin Role for a specific UID
/// Run this with: flutter run tools/set_admin.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use a targeted prompt or hardcoded for this one-time fix
  const String targetUid = 'qxXTqA7sbFbOIvcQxhpw1GSQ8K32'; // youssouphasba@gmail.com
  const String targetRole = 'superAdmin';

  // ignore: avoid_print
  print('--- TONTETIC ADMIN SETUP ---');
  
  try {
    await Firebase.initializeApp();
    // ignore: avoid_print
    print('Connected to Firebase.');

    await FirebaseFirestore.instance.collection('users').doc(targetUid).set({
      'role': targetRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ignore: avoid_print
    print('SUCCESS: Account $targetUid is now $targetRole.');
    exit(0);
  } catch (e) {
    // ignore: avoid_print
    print('ERROR: $e');
    exit(1);
  }
}
