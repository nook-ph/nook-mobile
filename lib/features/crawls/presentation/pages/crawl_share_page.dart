import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_share_overlays.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/injection_container.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

/// Puts the crawl's stats over a photo of the user's choosing and hands the
/// image to the OS share sheet (Instagram Stories included).
///
/// Two exports: the photo with the overlay on it, or the overlay alone as a
/// transparent PNG to place over a photo inside another app.
class CrawlSharePage extends StatefulWidget {
  const CrawlSharePage({super.key, required this.run, this.stampStop});

  final CrawlRun run;

  /// Set when sharing a single stop mid-crawl; opens on the Stamp layout.
  final CrawlStop? stampStop;

  @override
  State<CrawlSharePage> createState() => _CrawlSharePageState();
}

class _CrawlSharePageState extends State<CrawlSharePage> {
  final _compositeKey = GlobalKey();
  final _overlayKey = GlobalKey();
  final _picker = ImagePicker();

  late CrawlOverlayLayout _layout;
  File? _photo;
  bool _busy = false;

  /// Lifts toasts clear of the sticky Share bar.
  static const _barHeight = 122.0;

  /// 360 logical × 3 = 1080 px wide, the Instagram Story width.
  static const _exportPixelRatio = 3.0;

  List<CrawlOverlayLayout> get _layouts => [
    if (widget.stampStop != null) CrawlOverlayLayout.stamp,
    CrawlOverlayLayout.stacked,
    CrawlOverlayLayout.strip,
    CrawlOverlayLayout.route,
  ];

  @override
  void initState() {
    super.initState();
    _layout = _layouts.first;
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2160,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;
      setState(() => _photo = File(picked.path));
    } catch (e) {
      debugPrint('[CrawlShare] pick failed: $e');
      if (mounted) showPrimaryToast(context, "Couldn't open your photos.");
    }
  }

  Future<void> _share({required bool overlayOnly}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    try {
      final key = overlayOnly ? _overlayKey : _compositeKey;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _exportPixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('PNG encoding returned no data');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/nook-crawl-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          // Required on iPadOS, where the share popover needs an anchor.
          sharePositionOrigin: origin,
        ),
      );

      sl<AnalyticsService>().logEvent(
        'crawl_recap_shared',
        properties: {
          'layout': _layout.name,
          'mode': overlayOnly ? 'overlay' : 'photo',
          'has_photo': _photo != null,
        },
      );
    } catch (e, st) {
      debugPrint('[CrawlShare] share failed: $e\n$st');
      // Tapping Share again is the retry: layout and photo are kept.
      if (mounted) {
        showPrimaryToast(
          context,
          "Couldn't create the image.",
          bottomOffset: _barHeight,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListsTokens.surface,
      appBar: AppBar(
        backgroundColor: ListsTokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: ListsTokens.surface,
        titleSpacing: 0,
        leading: AdaptiveTap(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(LucideIcons.x, size: 24, color: ListsTokens.ink),
          ),
        ),
        title: Text('Share', style: crawlText(16, weight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(crawlGutter, 4, crawlGutter, 24),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              // Figma: the 360 x 640 story at 0.58.
              child: SizedBox(
                width: 208.8,
                height: 371.2,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _compositeKey,
                    child: SizedBox.fromSize(
                      size: CrawlShareOverlay.size,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _Backdrop(photo: _photo),
                          RepaintBoundary(
                            key: _overlayKey,
                            child: CrawlShareOverlay(
                              layout: _layout,
                              run: widget.run,
                              stampStop: widget.stampStop,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final layout in _layouts)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: layout == _layout
                        ? ListsTokens.ink
                        : ListsTokens.border,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final layout in _layouts)
                _LayoutChip(
                  label: layout.label,
                  selected: layout == _layout,
                  onTap: () => setState(() => _layout = layout),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _PhotoButton(
                icon: LucideIcons.image,
                label: _photo == null ? 'Choose photo' : 'Change photo',
                onTap: () => _pick(ImageSource.gallery),
              ),
              _PhotoButton(
                label: 'Take photo',
                onTap: () => _pick(ImageSource.camera),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Pick Instagram Stories in the share sheet to post it.',
            textAlign: TextAlign.center,
            style: crawlText(12, color: ListsTokens.muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(crawlGutter, 12, crawlGutter, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CrawlPrimaryButton(
              label: _busy ? 'Preparing…' : 'Share',
              icon: LucideIcons.share,
              onTap: _busy ? null : () => _share(overlayOnly: false),
            ),
            const SizedBox(height: 6),
            CrawlTextButton(
              label: 'Share the overlay only (transparent)',
              color: ListsTokens.muted,
              fontSize: 12,
              minHeight: 40,
              onTap: _busy ? null : () => _share(overlayOnly: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// The user's photo, or a dark field when they haven't picked one, so the
/// default export still looks deliberate.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.photo});

  final File? photo;

  @override
  Widget build(BuildContext context) {
    final file = photo;
    if (file != null) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return const ColoredBox(color: Color(0xFF2A302B));
  }
}

class _LayoutChip extends StatelessWidget {
  const _LayoutChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          // Figma: 7 / 14 around 12pt text; the outline adds its own 1.
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 15,
            vertical: selected ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: selected ? ListsTokens.brand : ListsTokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: selected ? null : Border.all(color: ListsTokens.border),
          ),
          child: Text(
            label,
            style: crawlText(
              12,
              weight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? ListsTokens.surface : ListsTokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({this.icon, required this.label, required this.onTap});

  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CrawlPillButton(
      label: label,
      icon: icon,
      onTap: onTap,
      outlined: true,
      height: 38,
      tapHeight: 38,
    );
  }
}
