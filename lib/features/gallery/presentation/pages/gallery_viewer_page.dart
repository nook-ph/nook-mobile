import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_photo_options.dart';

/// The viewer's dark ground and its text colours. Derived from the profile's
/// ink, so the dark stays green-black rather than pure black.
class _ViewerTokens {
  static const ground = Color(0xFF0E1110);
  static const text = Color(0xFFF4F5F3);
  static const muted = Color(0xFFB4B8B5);
  static const chip = Color(0x29FFFFFF);
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// "March 2026": the month is honest for both an EXIF date and an upload
/// date, where a day would look precise when it may not be.
String galleryMonthLabel(DateTime date) =>
    '${_months[date.month - 1]} ${date.year}';

/// One photo at a time, full screen, swiping through the gallery in grid
/// order. The cafe is a chip that opens the cafe page; the owner gets "…"
/// (Luma's caption panel, Canopi's top bar; docs/references/coffee-gallery).
class GalleryViewerPage extends StatefulWidget {
  const GalleryViewerPage({
    super.key,
    required this.initialPhotoId,
    required this.onOpenCafe,
    this.isOwner = true,
    this.onOpenReview,
  });

  final String initialPhotoId;
  final bool isOwner;
  final ValueChanged<String> onOpenCafe;
  final VoidCallback? onOpenReview;

  /// Pushes the viewer over [context], sharing its [GalleryCubit].
  static Future<void> open(
    BuildContext context, {
    required GalleryPhoto photo,
    required ValueChanged<String> onOpenCafe,
    VoidCallback? onOpenReview,
    bool isOwner = true,
  }) {
    final cubit = context.read<GalleryCubit>();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => BlocProvider.value(
          value: cubit,
          child: GalleryViewerPage(
            initialPhotoId: photo.id,
            isOwner: isOwner,
            onOpenCafe: onOpenCafe,
            onOpenReview: onOpenReview,
          ),
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<GalleryViewerPage> createState() => _GalleryViewerPageState();
}

class _GalleryViewerPageState extends State<GalleryViewerPage> {
  late String _currentId = widget.initialPhotoId;
  PageController? _controller;

  List<GalleryPhoto> _visible(GalleryState state) => widget.isOwner
      ? state.photos
      : state.photos.where((p) => !p.isHidden).toList();

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _more(GalleryPhoto photo) async {
    final deleted = await showGalleryPhotoOptions(
      context,
      cubit: context.read<GalleryCubit>(),
      photo: photo,
      onOpenReview: widget.onOpenReview == null
          ? null
          : () {
              Navigator.of(context).pop();
              widget.onOpenReview!();
            },
    );
    if (!mounted || !deleted) return;
    if (_visible(context.read<GalleryCubit>().state).isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _ViewerTokens.ground,
        body: BlocBuilder<GalleryCubit, GalleryState>(
          builder: (context, state) {
            final photos = _visible(state);
            if (photos.isEmpty) return const SizedBox.shrink();
            var index = photos.indexWhere((p) => p.id == _currentId);
            if (index < 0) {
              // The photo on screen was deleted: stay at the same place.
              index = (_controller?.hasClients ?? false)
                  ? (_controller!.page?.round() ?? 0).clamp(
                      0,
                      photos.length - 1,
                    )
                  : 0;
              _currentId = photos[index].id;
            }
            _controller ??= PageController(initialPage: index);
            final photo = photos[index];

            return SafeArea(
              child: Column(
                // Stretch, so the caption starts at the left edge rather
                // than centring under the photo.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    position: '${index + 1} of ${photos.length}',
                    onClose: () => Navigator.of(context).pop(),
                    onMore: widget.isOwner ? () => _more(photo) : null,
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: photos.length,
                      onPageChanged: (i) =>
                          setState(() => _currentId = photos[i].id),
                      itemBuilder: (_, i) => InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Semantics(
                          image: true,
                          label: _photoLabel(photos[i]),
                          child: GalleryImage(
                            url: photos[i].imageUrl,
                            fit: BoxFit.contain,
                            dark: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _Caption(
                    photo: photo,
                    isOwner: widget.isOwner,
                    onOpenCafe: () => widget.onOpenCafe(photo.cafeId),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _photoLabel(GalleryPhoto photo) {
  final drink = photo.drinkName;
  return drink == null
      ? 'Photo at ${photo.cafeName}'
      : '$drink at ${photo.cafeName}';
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.position, required this.onClose, this.onMore});

  final String position;
  final VoidCallback onClose;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 4),
          _RoundIcon(icon: LucideIcons.x, label: 'Close', onTap: onClose),
          Expanded(
            child: Text(
              position,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _ViewerTokens.muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (onMore != null)
            _RoundIcon(
              icon: LucideIcons.ellipsis,
              label: 'Photo options',
              onTap: onMore!,
            )
          else
            const SizedBox(width: 44),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: _ViewerTokens.chip,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: _ViewerTokens.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// Under the photo: what it was, where (a chip to the cafe), and when.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.photo,
    required this.isOwner,
    required this.onOpenCafe,
  });

  final GalleryPhoto photo;
  final bool isOwner;
  final VoidCallback onOpenCafe;

  @override
  Widget build(BuildContext context) {
    final drink = photo.drinkName;
    final notes = [
      galleryMonthLabel(photo.takenAt),
      if (isOwner && photo.isPinned) 'Pinned',
      if (isOwner && photo.isHidden) 'Hidden from your profile',
      if (photo.isFromReview) 'From a review',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (drink != null) ...[
            Text(
              drink,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: _ViewerTokens.text,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Semantics(
            button: true,
            label: 'Open ${photo.cafeName}',
            excludeSemantics: true,
            child: AdaptiveTap(
              onTap: onOpenCafe,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                decoration: BoxDecoration(
                  color: _ViewerTokens.chip,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 16,
                      color: _ViewerTokens.text,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        photo.cafeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _ViewerTokens.text,
                        ),
                      ),
                    ),
                    if (photo.cafeArea != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          photo.cafeArea!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: _ViewerTokens.muted,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 2),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: _ViewerTokens.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            notes.join(' · '),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _ViewerTokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}
