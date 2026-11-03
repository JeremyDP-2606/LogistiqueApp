// Envoi des preuves (photos, signatures) sur S3.
// Accès « protected » : seul le livreur qui a pris la preuve peut la modifier ; lecture réservée aux
// utilisateurs connectés (la V1 utilise « guest », lisible par tous : à corriger).
import 'dart:typed_data';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:uuid/uuid.dart';

import 'demo_hooks.dart';

class ProofUpload {
  static Future<String> bytes(Uint8List data, {required String tourId, required String kind, String ext = 'jpg'}) async {
    if (DemoHooks.upload != null) return DemoHooks.upload!(data, kind);
    final key = 'preuves/$tourId/$kind-${const Uuid().v4()}.$ext';
    await Amplify.Storage.uploadData(
      key: key,
      data: S3DataPayload.bytes(data, contentType: ext == 'png' ? 'image/png' : 'image/jpeg'),
      options: const StorageUploadDataOptions(accessLevel: StorageAccessLevel.protected),
    ).result;
    return key;
  }
}
