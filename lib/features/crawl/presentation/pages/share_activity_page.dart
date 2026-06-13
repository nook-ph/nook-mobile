import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_state.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/crawl_share_card.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card_view.dart';
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

  void _shareToInstagramStories() {
    // TODO: replace with instagram_stories_share when deep-link
    // to Instagram Stories is confirmed viable on PH devices.
    _shareCardCubit.captureAndShare();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(
      ClipboardData(text: 'Nook Crawl — ${widget.crawlTitle}'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
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

      await ImageGallerySaverPlus.saveImage(bytes, name: 'nook_crawl');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to gallery')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _copyLink() async {
    final deepLink = 'nook://crawl/${widget.crawlId}';
    await Clipboard.setData(ClipboardData(text: deepLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied')),
      );
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
          switch (state) {
            case ShareCardCapturing():
              setState(() => _isCapturing = true);
            case ShareCardShared():
            case ShareCardError():
              setState(() => _isCapturing = false);
              if (state case ShareCardError(:final message)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              }
            default:
              break;
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
                          _ => const SizedBox.shrink(),
                        };
                      },
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CarouselDot(active: true),
                          Gap(6),
                          _CarouselDot(active: false),
                          Gap(6),
                          _CarouselDot(active: false),
                        ],
                      ),
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
                            onTap:
                                _isCapturing ? null : _shareToInstagramStories,
                          ),
                          const Gap(8),
                          _ShareDestinationButton(
                            icon:
                                const Icon(LucideIcons.clipboardCopy, size: 22),
                            label: 'Copy to\nClipboard',
                            onTap: _copyToClipboard,
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
                            icon: const Icon(LucideIcons.link, size: 22),
                            label: 'Copy Link',
                            onTap: _copyLink,
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
                                : () =>
                                    _shareCardCubit.captureAndShare(),
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
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F1F0F),
              borderRadius: BorderRadius.circular(12),
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
        child: AspectRatio(
          aspectRatio: 360 / 640,
          child: CrawlShareCard(data: data),
        ),
      ),
    );
  }

  Widget _buildErrorPreview(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
    );
  }
}

class _CarouselDot extends StatelessWidget {
  final bool active;

  const _CarouselDot({required this.active});

  @override
  Widget build(BuildContext context) {
    if (active) {
      return Container(
        width: 20,
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFF344E41),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
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
