import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import '../api_key.dart';

Future<String> uploadAudioToGCS(String filePath) async {
  late Map<String, dynamic> _credentials;
  final bucketName = google_cloud_bucket_name;
  final destinationName =
      'audio/${DateTime.now().millisecondsSinceEpoch}_converted.wav';

  final credentialsContent = await rootBundle
      .loadString('assets/credentials/google_cloud_credentials.json');
  print("Loaded credentials: $credentialsContent");
  _credentials = jsonDecode(credentialsContent);
  final accountCredentials = ServiceAccountCredentials.fromJson(_credentials);

  final scopes = [storage.StorageApi.devstorageFullControlScope];

  final client = await clientViaServiceAccount(accountCredentials, scopes);

  try {
    final storageApi = storage.StorageApi(client);

    final fileToUpload = File(filePath);
    final media =
        storage.Media(fileToUpload.openRead(), fileToUpload.lengthSync());

    final object = storage.Object()..name = destinationName;

    final uploadedObject = await storageApi.objects.insert(
      object,
      bucketName,
      uploadMedia: media,
    );

    // Construct the GCS URI for the uploaded file.
    final gcsUri = 'gs://$bucketName/$destinationName';
    print('File uploaded to: $gcsUri');
    return gcsUri;
  } finally {
    client.close();
  }
}
