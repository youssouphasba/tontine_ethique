import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a File (Mobile) to the specified path
  Future<String> uploadFile(String path, File file) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('StorageService: Error uploading file: $e');
      rethrow;
    }
  }

  /// Uploads raw bytes (Web) to the specified path
  Future<String> uploadData(String path, Uint8List data, String contentType) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = ref.putData(data, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('StorageService: Error uploading data: $e');
      rethrow;
    }
  }

  /// Deletes a file at the specified path
  Future<void> deleteFile(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (e) {
      debugPrint('StorageService: Error deleting file: $e');
    }
  }
}

// Provider if using Riverpod
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
