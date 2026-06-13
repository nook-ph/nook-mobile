import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nook/features/crawl/domain/use_cases/get_share_card_data_usecase.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_state.dart';

class ShareCardCubit extends Cubit<ShareCardState> {
  final GetShareCardDataUseCase _getShareCardDataUseCase;
  GlobalKey? _shareCardKey;

  ShareCardCubit({
    required GetShareCardDataUseCase getShareCardDataUseCase,
  })  : _getShareCardDataUseCase = getShareCardDataUseCase,
        super(const ShareCardInitial());

  void setShareCardKey(GlobalKey key) => _shareCardKey = key;

  Future<void> loadData(String crawlId) async {
    emit(const ShareCardLoading());

    final result = await _getShareCardDataUseCase.call(crawlId);
    switch (result) {
      case Right(value: final data):
        emit(ShareCardReady(data));
      case Left(value: final failure):
        emit(ShareCardError(failure.message));
    }
  }

  Future<RenderRepaintBoundary?> _getBoundary() async {
    final key = _shareCardKey;
    if (key == null) return null;
    return key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  }

  Future<Uint8List?> _captureFromBoundary(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<Uint8List> _compositeOverWhite(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    canvas.drawImage(image, Offset.zero, Paint());
    final picture = recorder.endRecording();
    final composited = await picture.toImage(image.width, image.height);
    final byteData = await composited.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> capturePngBytes() async {
    final boundary = await _getBoundary();
    if (boundary == null) throw Exception('Share card not ready');
    final bytes = await _captureFromBoundary(boundary);
    if (bytes == null) throw Exception('Failed to encode image');
    return bytes;
  }

  Future<String?> captureAndShare() async {
    try {
      final boundary = await _getBoundary();
      if (boundary == null) return 'Share card not ready';

      final bytes = await _captureFromBoundary(boundary);
      if (bytes == null) return 'Failed to encode image';

      final opaque = await _compositeOverWhite(bytes);

      await ImageGallerySaverPlus.saveImage(opaque);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nook_share_card.png');
      await file.writeAsBytes(opaque);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
      );

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
