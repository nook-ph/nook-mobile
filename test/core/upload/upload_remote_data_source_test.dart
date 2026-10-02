import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/core/upload/data/upload_remove_data_source.dart';

void main() {
  late Directory dir;
  late List<File> photos;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nook_upload_test');
    photos = [
      for (var i = 0; i < 3; i++)
        File('${dir.path}/photo_$i.jpg')..writeAsBytesSync([i]),
    ];
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('review photos upload side by side and come back in order', () async {
    var putsInFlight = 0;
    var mostPutsAtOnce = 0;
    final releasePuts = Completer<void>();

    final client = MockClient((request) async {
      if (request.method == 'POST') {
        final slot = (jsonDecode(request.body) as Map)['slot'];
        return http.Response(
          jsonEncode({
            'uploadUrl': 'https://upload.example/$slot',
            'objectKey': 'reviews/$slot.jpg',
            'publicUrl': 'https://cdn.example/reviews/$slot.jpg',
          }),
          200,
        );
      }

      putsInFlight++;
      if (putsInFlight > mostPutsAtOnce) mostPutsAtOnce = putsInFlight;
      if (putsInFlight == photos.length) releasePuts.complete();
      // Held until every photo's PUT has started: uploads one after another
      // would never get here.
      await releasePuts.future;
      putsInFlight--;
      return http.Response('', 200);
    });

    final uploaded =
        await UploadRemoteDataSource(
          httpClient: client,
          presignUrl: 'https://presign.example',
        ).uploadReviewImages(
          cafeId: 'cafe',
          userId: 'user',
          images: photos,
          accessToken: 'token',
        );

    expect(mostPutsAtOnce, photos.length);
    expect(uploaded.map((u) => u.slot), [0, 1, 2]);
    expect(uploaded.map((u) => u.objectKey), [
      'reviews/0.jpg',
      'reviews/1.jpg',
      'reviews/2.jpg',
    ]);
  });

  test('no photos means no requests', () async {
    final client = MockClient((_) async => fail('nothing to upload'));

    final uploaded = await UploadRemoteDataSource(
      httpClient: client,
      presignUrl: 'https://presign.example',
    ).uploadReviewImages(cafeId: 'cafe', userId: 'user', images: const []);

    expect(uploaded, isEmpty);
  });
}
