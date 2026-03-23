import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:aco_plus/app/core/services/push_notification_service.dart';
import 'package:aco_plus/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

class FirebaseService implements Service {
  @override
  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirestoreClient.init();
    initFirebaseMessaging();
  }

  static Future<String> uploadFile({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    required String path,
  }) async {
    final folderRef = FirebaseStorage.instance.ref().child(path);
    final Reference fileRef = folderRef.child(name);
    await fileRef.putData(bytes, SettableMetadata(contentType: mimeType));
    return await fileRef.getDownloadURL();
  }
}
