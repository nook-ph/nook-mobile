import 'dart:io';
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

  Future<void> captureAndShare() async {
    final key = _shareCardKey;
    if (key == null) {
      emit(const ShareCardError('Share card not ready'));
      return;
    }

    emit(const ShareCardCapturing());

    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        emit(const ShareCardError('Could not find share card renderer'));
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        emit(const ShareCardError('Failed to encode image'));
        return;
      }

      final bytes = byteData.buffer.asUint8List();

      await ImageGallerySaverPlus.saveImage(bytes);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nook_share_card.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
      );

      emit(const ShareCardShared());
    } catch (e) {
      emit(ShareCardError(e.toString()));
    }
  }
}
