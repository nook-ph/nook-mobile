import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/social_handle.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/presentation/share/cup_story_overlay.dart';
import 'package:nook/injection_container.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opens "Share your cup" for one of your own cups
/// (docs/features/share_cup_story.md §3). [entry] is one of
/// [CupShareEntry]. [instagramRaw] is the cafe's `social_links.instagram`
/// when the caller has it; otherwise the sheet reads it. [photoId] picks the
/// photo to start on (the story viewer's).
Future<void> showCupShareSheet(
  BuildContext context, {
  required CupCard cup,
  required String cafeId,
  required String cafeName,
  String? cafeArea,
  String? instagramRaw,
  required String entry,
  String? photoId,
}) {
  dismissToasts();
  return ReviewSheetShell.show<void>(
    context,
    builder: (_) => CupShareSheet(
      cup: cup,
      cafeId: cafeId,
      cafeName: cafeName,
      cafeArea: cafeArea,
      instagramRaw: instagramRaw,
      entry: entry,
      photoId: photoId,
    ),
  );
}

/// Like the crawl's share page: the cup's overlay on one of its photos
/// (or one you choose), handed to the OS share sheet, Instagram Stories
/// included; or the overlay alone as a transparent PNG. Copy link and the
/// cafe's @handle go through the clipboard, for a Link or Mention sticker.
class CupShareSheet extends StatefulWidget {
  const CupShareSheet({
    super.key,
    required this.cup,
    required this.cafeId,
    required this.cafeName,
    required this.entry,
    this.cafeArea,
    this.instagramRaw,
    this.photoId,
    this.picker,
  });

  final CupCard cup;
  final String cafeId;
  final String cafeName;
  final String? cafeArea;
  final String? instagramRaw;
  final String entry;
  final String? photoId;

  /// For tests.
  final ImagePicker? picker;

  @override
  State<CupShareSheet> createState() => _CupShareSheetState();
}

enum _Load { loading, ready, failed }

class _CupShareSheetState extends State<CupShareSheet> {
  static const _photoTimeout = Duration(seconds: 10);

  final _compositeKey = GlobalKey();
  final _overlayKey = GlobalKey();
  late final _picker = widget.picker ?? ImagePicker();
  late final List<CupItem> _photos = [
    for (final p in widget.cup.photos)
      if (!p.isHidden) p,
  ];
  late final PageController _pager;

  int _index = 0;

  /// A photo from the device, used instead of the cup's.
  File? _picked;
  _Load _load = _Load.ready;
  String? _handle;
  bool _busy = false;
  bool _precached = false;

  bool get _onPhoto => _picked != null || _photos.isNotEmpty;

  String get _layout => _onPhoto ? 'photo' : 'note';

  @override
  void initState() {
    super.initState();
    final start = _photos.indexWhere((p) => p.photoId == widget.photoId);
    _index = start < 0 ? 0 : start;
    _pager = PageController(initialPage: _index);
    logAppEvent(
      CupShareEvents.opened,
      properties: {
        'cafe_id': widget.cafeId,
        'cup_id': widget.cup.cupId ?? '',
        'entry': widget.entry,
        'has_photo': _photos.isNotEmpty,
        'photo_count': _photos.length,
        'layout': _layout,
      },
    );
    unawaited(_cleanTempFiles());
    unawaited(_loadHandle());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // precacheImage needs the context's MediaQuery, so not in initState.
    if (_photos.isNotEmpty && !_precached) {
      _precached = true;
      _precache();
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _loadHandle() async {
    final raw = widget.instagramRaw ?? await _readInstagram();
    final handle = raw == null ? null : socialHandle(raw);
    if (mounted && handle != null) setState(() => _handle = handle);
  }

  Future<String?> _readInstagram() async {
    if (!sl.isRegistered<SupabaseClient>()) return null;
    try {
      final row = await sl<SupabaseClient>()
          .from('cafes')
          .select('social_links')
          .eq('id', widget.cafeId)
          .maybeSingle();
      final links = row?['social_links'];
      return links is Map ? links['instagram'] as String? : null;
    } catch (_) {
      return null; // no handle row; nothing else depends on it
    }
  }

  ImageProvider _provider(int i) =>
      CachedNetworkImageProvider(_photos[i].imageUrl!);

  /// The image is captured as painted, so the photo must be decoded first.
  Future<void> _precache() async {
    setState(() => _load = _Load.loading);
    var failed = false;
    await precacheImage(
      _provider(_index),
      context,
      onError: (_, _) => failed = true,
    ).timeout(_photoTimeout, onTimeout: () => failed = true);
    if (!mounted) return;
    setState(() => _load = failed ? _Load.failed : _Load.ready);
    if (failed) _logFailed('render', 'none', 'PhotoLoadTimeout');
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2160,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      await precacheImage(FileImage(file), context);
      if (!mounted) return;
      setState(() {
        _picked = file;
        _load = _Load.ready;
      });
    } catch (e) {
      debugPrint('[CupShare] pick failed: $e');
      if (mounted) {
        showPrimaryToast(
          context,
          source == ImageSource.camera
              ? "Couldn't open the camera."
              : "Couldn't open your photos.",
        );
      }
    }
  }

  /// Shared files are read after we've moved on, so they're only removed
  /// an hour later, the next time the sheet opens.
  Future<void> _cleanTempFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      await for (final f in dir.list()) {
        if (f is File &&
            f.uri.pathSegments.last.startsWith('nook-cup-') &&
            (await f.lastModified()).isBefore(cutoff)) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  String _link() =>
      ShareService.cupLink(widget.cup.cupId ?? widget.cup.id, ref: 'cup_share');

  Future<void> _share({required bool overlayOnly}) async {
    if (_busy || _load != _Load.ready) return;
    setState(() => _busy = true);
    final target = overlayOnly ? 'overlay' : 'system';
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    var stage = 'render';
    try {
      // Let a page change or a photo's first paint land first.
      await WidgetsBinding.instance.endOfFrame;
      final key = overlayOnly ? _overlayKey : _compositeKey;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 360 logical × 3 = 1080 px wide, the Instagram Story width.
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('PNG encoding returned no data');

      stage = 'write_file';
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/nook-cup-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      final title = 'My cup at ${widget.cafeName} on Nook';
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          // Many targets (Instagram among them) drop the text with a file;
          // the URL is printed on the image for that.
          text: '$title\n\n${_link()}',
          subject: title,
          // Required on iPadOS, where the share popover needs an anchor.
          sharePositionOrigin: origin,
        ),
      );
      _logShared(target, result.status.name);
    } catch (e, st) {
      debugPrint('[CupShare] share failed: $e\n$st');
      _logFailed(stage, target, e);
      // Tapping Share again is the retry: the photo is kept.
      if (mounted) showPrimaryToast(context, "Couldn't create the image.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _link()));
    _logShared('copy_link', 'success');
    if (mounted) showPrimaryToast(context, 'Link copied');
  }

  Future<void> _copyHandle() async {
    final handle = _handle;
    if (handle == null) return;
    await Clipboard.setData(ClipboardData(text: '@$handle'));
    logAppEvent(
      CupShareEvents.handleCopied,
      properties: {'cafe_id': widget.cafeId, 'entry': 'share_sheet'},
    );
    if (mounted) {
      showPrimaryToast(
        context,
        '@$handle copied. Paste it in a Mention sticker.',
      );
    }
  }

  void _logShared(String target, String result) {
    logAppEvent(
      CupShareEvents.shared,
      properties: {
        'cafe_id': widget.cafeId,
        'cup_id': widget.cup.cupId ?? '',
        'entry': widget.entry,
        'target': target,
        'result': result,
        'layout': _layout,
        'photo_source': _picked != null
            ? 'device'
            : _photos.isEmpty
            ? 'none'
            : 'cup',
        'photo_index': _index,
        'has_handle': _handle != null,
      },
    );
  }

  void _logFailed(String stage, String target, Object error) {
    logAppEvent(
      CupShareEvents.failed,
      properties: {
        'stage': stage,
        'target': target,
        'error': error is String ? error : error.runtimeType.toString(),
      },
    );
  }

  void _onPage(int i) {
    setState(() => _index = i);
    _precache();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _load == _Load.ready && !_busy;
    return ReviewSheetShell(
      title: 'Share your cup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(child: _preview()),
          if (_picked == null && _photos.length > 1) ...[
            const SizedBox(height: 12),
            _Dots(count: _photos.length, index: _index),
          ],
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: LucideIcons.image,
                label: _picked == null ? 'Choose photo' : 'Change photo',
                onTap: () => _pick(ImageSource.gallery),
              ),
              _Pill(
                icon: LucideIcons.camera,
                label: 'Take photo',
                onTap: () => _pick(ImageSource.camera),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pick Instagram Stories in the share sheet to post it.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: ReviewTokens.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ReviewPrimaryButton(
            label: 'Share',
            icon: LucideIcons.share,
            busy: _busy || _load == _Load.loading,
            busyLabel: 'Preparing…',
            onTap: ready ? () => _share(overlayOnly: false) : null,
          ),
          _QuietButton(
            label: 'Share the overlay only (transparent)',
            onTap: ready ? () => _share(overlayOnly: true) : null,
          ),
          const SizedBox(height: 4),
          _CopyRow(
            text: 'Link to your cup',
            hint: 'For a Link sticker',
            action: 'Copy',
            onTap: _copyLink,
          ),
          if (_handle != null) ...[
            const SizedBox(height: 8),
            _CopyRow(
              text: 'Tag the café: @$_handle',
              hint: 'For a Mention sticker',
              action: 'Copy',
              onTap: _copyHandle,
            ),
          ],
        ],
      ),
    );
  }

  /// 208 × 370: the 360 × 640 story at 0.58, as on the crawl share page.
  Widget _preview() {
    final overlay = RepaintBoundary(
      key: _overlayKey,
      child: CupStoryOverlay(
        cup: widget.cup,
        cafeName: widget.cafeName,
        cafeArea: widget.cafeArea,
        onPhoto: _onPhoto,
      ),
    );
    final picked = _picked;
    final Widget background = picked != null
        ? Image.file(picked, fit: BoxFit.cover)
        : _photos.isEmpty
        ? const ColoredBox(color: CupStoryOverlay.noteGround)
        : _photos.length == 1
        ? Image(image: _provider(0), fit: BoxFit.cover)
        : PageView.builder(
            controller: _pager,
            itemCount: _photos.length,
            onPageChanged: _onPage,
            itemBuilder: (_, i) =>
                Image(image: _provider(i), fit: BoxFit.cover),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 208.8,
        height: 371.2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              child: RepaintBoundary(
                key: _compositeKey,
                child: SizedBox.fromSize(
                  size: CupStoryOverlay.size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      background,
                      // Swipes reach the photo pager under the words.
                      IgnorePointer(child: overlay),
                    ],
                  ),
                ),
              ),
            ),
            if (_load == _Load.failed && _picked == null)
              _PhotoFailed(onRetry: _precache),
          ],
        ),
      ),
    );
  }
}

class _PhotoFailed extends StatelessWidget {
  const _PhotoFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xE60A0F0D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Couldn't load your photo. Check your connection.",
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: ReviewTokens.surface,
              ),
            ),
            const SizedBox(height: 8),
            AdaptiveTap(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                child: Text(
                  'Retry',
                  style: context.textTheme.bodyMediumMed.copyWith(
                    color: ReviewTokens.surface,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == index ? ReviewTokens.ink : ReviewTokens.border,
              ),
            ),
        ],
      ),
    );
  }
}

/// Outlined photo action, as on the crawl share page.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ReviewTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: ReviewTokens.ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.textTheme.bodyMediumMed.copyWith(
                  color: ReviewTokens.ink,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietButton extends StatelessWidget {
  const _QuietButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: ReviewTokens.muted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// A value on the left and its Copy action on the right (Spoil me).
class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.text,
    required this.hint,
    required this.action,
    required this.onTap,
  });

  final String text;
  final String hint;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        color: ReviewTokens.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMediumMed.copyWith(
                      color: ReviewTokens.ink,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    hint,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: ReviewTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '$action ${text.toLowerCase()}',
            excludeSemantics: true,
            child: AdaptiveTap(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                child: Text(
                  action,
                  style: context.textTheme.bodyMediumMed.copyWith(
                    color: ReviewTokens.brand,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
