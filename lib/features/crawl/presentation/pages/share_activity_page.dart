import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:appinio_social_share/appinio_social_share.dart';
import 'package:path_provider/path_provider.dart';

import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_state.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/crawl_share_card.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/transparency_grid.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card_view.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/injection_container.dart';

class ShareActivityPage extends StatefulWidget {
  final String crawlId;
  final String crawlTitle;
  final ShareCardCubit? cubit;

  const ShareActivityPage({
    super.key,
    required this.crawlId,
    required this.crawlTitle,
    this.cubit,
  });

  @override
  State<ShareActivityPage> createState() => _ShareActivityPageState();
}

class _ShareActivityPageState extends State<ShareActivityPage> {
  late final ShareCardCubit _shareCardCubit;
  final _shareCardKey = GlobalKey();
  bool _ownsCubit = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _shareCardCubit = widget.cubit ?? sl<ShareCardCubit>();
    _ownsCubit = widget.cubit == null;
    _shareCardCubit.setShareCardKey(_shareCardKey);
    if (_shareCardCubit.state is! ShareCardReady) {
      _shareCardCubit.loadData(widget.crawlId);
    }
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      _shareCardCubit.close();
    }
    super.dispose();
  }

  Future<Uint8List?> _capturePngBytes() async {
    final boundary =
        _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

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

  Future<void> _shareToInstagramStories() async {
    try {
      setState(() => _isCapturing = true);
      final bytes = await _capturePngBytes();
      if (bytes == null) {
        if (mounted) showPrimaryToast(context, 'Failed to capture image');
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nook_share.png');
      await file.writeAsBytes(bytes);

      final share = AppinioSocialShare();
      final result = Platform.isIOS
          ? await share.iOS.shareToInstagramStory(
              '',
              stickerImage: file.path,
              backgroundTopColor: '#1A1A1A',
              backgroundBottomColor: '#1A1A1A',
              attributionURL: 'nook://crawl/${widget.crawlId}',
            )
          : await share.android.shareToInstagramStory(
              '',
              stickerImage: file.path,
              backgroundTopColor: '#1A1A1A',
              backgroundBottomColor: '#1A1A1A',
              attributionURL: 'nook://crawl/${widget.crawlId}',
            );

      if (result != 'SUCCESS' && mounted) {
        showPrimaryToast(context, 'Instagram not available');
      }
    } catch (e) {
      if (mounted) showPrimaryToast(context, 'Failed to share to Instagram');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _downloadToGallery() async {
    try {
      final bytes = await _capturePngBytes();
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to capture image')),
          );
        }
        return;
      }

      final opaque = await _compositeOverWhite(bytes);
      await ImageGallerySaverPlus.saveImage(opaque, name: 'nook_crawl');

      if (mounted) {
        showPrimaryToast(context, 'Saved to gallery');
      }
    } catch (e) {
      if (mounted) {
        showPrimaryToast(context, 'Failed to save');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShareCardCubit>.value(
      value: _shareCardCubit,
      child: BlocListener<ShareCardCubit, ShareCardState>(
        listenWhen: (previous, current) =>
            previous.runtimeType != current.runtimeType,
        listener: (context, state) {
          if (state case ShareCardError(:final message)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(LucideIcons.x),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Share Activity'),
            elevation: 0,
            backgroundColor: Colors.white,
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    flex: 1,
                    child: BlocBuilder<ShareCardCubit, ShareCardState>(
                      builder: (context, state) {
                        return switch (state) {
                          ShareCardInitial() || ShareCardLoading() =>
                            _buildLoadingPreview(),
                          ShareCardReady(:final data) =>
                            _buildCardPreview(data),
                          ShareCardError(:final message) =>
                            _buildErrorPreview(message),
                        };
                      },
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Share to',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 100,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _ShareDestinationButton(
                            icon: const Icon(LucideIcons.camera, size: 22),
                            label: 'Instagram\nStories',
                            enabled: !_isCapturing,
                            onTap: _isCapturing ? null : _shareToInstagramStories,
                          ),
                          const Gap(8),
                          _ShareDestinationButton(
                            icon: const Icon(LucideIcons.download, size: 22),
                            label: 'Download',
                            enabled: !_isCapturing,
                            onTap: _isCapturing ? null : _downloadToGallery,
                          ),
                          const Gap(8),
                          _ShareDestinationButton(
                            icon: _isCapturing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(LucideIcons.share2, size: 22),
                            label: 'More',
                            enabled: !_isCapturing,
                            onTap: _isCapturing
                                ? null
                                : () async {
                                    setState(() => _isCapturing = true);
                                    final error =
                                        await _shareCardCubit.captureAndShare();
                                    if (!context.mounted) return;
                                    setState(() => _isCapturing = false);
                                    if (error != null) {
                                      showPrimaryToast(context, error);
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 16,
                  ),
                ],
              ),
              Positioned(
                left: -9999,
                top: 0,
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: const ShareCardView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPreview() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AspectRatio(
          aspectRatio: 360 / 640,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                const Positioned.fill(child: TransparencyGrid()),
                const SizedBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview(CrawlShareCardData data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 360 / 640,
            child: Stack(
              children: [
                const Positioned.fill(child: TransparencyGrid()),
                CrawlShareCard(data: data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPreview(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 360 / 640,
            child: Stack(
              children: [
                const Positioned.fill(child: TransparencyGrid()),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => _shareCardCubit.loadData(widget.crawlId),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareDestinationButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _ShareDestinationButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(child: icon),
          ),
          const Gap(6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
