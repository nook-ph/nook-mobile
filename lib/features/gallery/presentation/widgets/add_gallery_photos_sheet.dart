import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_photo_options.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// Saves [photos] to [cafe] with an optional drink and note. Throws on
/// failure. The sheet waits for it, so a callback that only starts the
/// upload (the gallery's +) lets the sheet close at once.
typedef SaveGalleryPhotos =
    Future<void> Function({
      required PickedCafe cafe,
      required List<PickedGalleryPhoto> photos,
      String? drinkName,
      String? caption,
    });

/// Opens the add sheet. Returns true when the photos were saved.
///
/// [waitsForUpload] says [onSave] holds the sheet open for the whole
/// upload (the ranking reveal). Then only the close button or Back closes
/// it, and neither works mid-upload, so the result is never lost.
Future<bool> showAddGalleryPhotosSheet(
  BuildContext context, {
  required List<PickedGalleryPhoto> photos,
  required PickedCafe cafe,
  required SaveGalleryPhotos onSave,
  Future<PickedCafe?> Function()? onChangeCafe,
  bool waitsForUpload = false,
}) async {
  final saved = await ListsSheet.show<bool>(
    context,
    isDismissible: !waitsForUpload,
    builder: (_) => AddGalleryPhotosSheet(
      photos: photos,
      cafe: cafe,
      onSave: onSave,
      onChangeCafe: onChangeCafe,
    ),
  );
  return saved == true;
}

/// The last step before photos join the gallery: the photos, the cafe they
/// belong to, and an optional "What did you have?". One cafe and one drink
/// for the whole batch, as Instagram does with a post's location.
///
/// With [onChangeCafe] null the cafe is fixed (the ranking reveal: the cafe
/// was just ranked). Thumbnails take Instagram's place beside the field for
/// one photo and Buy Me a Coffee's row with remove badges for several.
class AddGalleryPhotosSheet extends StatefulWidget {
  const AddGalleryPhotosSheet({
    super.key,
    required this.photos,
    required this.cafe,
    required this.onSave,
    this.onChangeCafe,
  });

  final List<PickedGalleryPhoto> photos;
  final PickedCafe cafe;
  final SaveGalleryPhotos onSave;
  final Future<PickedCafe?> Function()? onChangeCafe;

  @override
  State<AddGalleryPhotosSheet> createState() => _AddGalleryPhotosSheetState();
}

class _AddGalleryPhotosSheetState extends State<AddGalleryPhotosSheet> {
  late List<PickedGalleryPhoto> _photos = [...widget.photos];
  late PickedCafe _cafe = widget.cafe;
  final _drink = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  bool _failed = false;
  String? _textError;

  @override
  void dispose() {
    _drink.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _changeCafe() async {
    final change = widget.onChangeCafe;
    if (change == null || _saving) return;
    final next = await change();
    if (next != null && mounted) setState(() => _cafe = next);
  }

  void _remove(PickedGalleryPhoto photo) {
    if (_saving || _photos.length <= 1) return;
    setState(() => _photos = [..._photos]..remove(photo));
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final textError = galleryTextError(_drink.text, _note.text);
    if (textError != null) {
      setState(() => _textError = textError);
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
      _textError = null;
    });
    try {
      await widget.onSave(
        cafe: _cafe,
        photos: _photos,
        drinkName: _drink.text.trim().isEmpty ? null : _drink.text.trim(),
        caption: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _photos.length;
    return PopScope(
      canPop: !_saving,
      child: ListsSheet(
        title: count == 1 ? 'Add to your gallery' : 'Add $count photos',
        onClose: _saving ? () {} : null,
        children: [
          if (count == 1)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(photo: _photos.single, size: 88, busy: _saving),
                const SizedBox(width: 12),
                Expanded(
                  child: DrinkNameField(
                    controller: _drink,
                    enabled: !_saving,
                    onDone: _save,
                  ),
                ),
              ],
            )
          else ...[
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _Thumb(
                  photo: _photos[i],
                  size: 76,
                  busy: _saving,
                  onRemove: _saving ? null : () => _remove(_photos[i]),
                ),
              ),
            ),
            DrinkNameField(
              controller: _drink,
              enabled: !_saving,
              onDone: _save,
            ),
          ],
          GalleryNoteField(controller: _note, enabled: !_saving),
          if (_textError != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _textError!,
                style: listsText(13, color: ListsTokens.danger),
              ),
            ),
          _CafeRow(
            cafe: _cafe,
            onChange: widget.onChangeCafe == null ? null : _changeCafe,
          ),
          if (_failed)
            Semantics(
              liveRegion: true,
              child: Text(
                count == 1
                    ? "Couldn't add the photo. Check your connection and try "
                          'again.'
                    : "Couldn't add the photos. Check your connection and try "
                          'again.',
                style: listsText(13, color: ListsTokens.danger),
              ),
            ),
          ListsPillButton(
            label: _failed
                ? 'Try again'
                : count == 1
                ? 'Add photo'
                : 'Add $count photos',
            busy: _saving,
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.size,
    required this.busy,
    this.onRemove,
  });

  final PickedGalleryPhoto photo;
  final double size;
  final bool busy;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final remove = onRemove;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GalleryImage(
              url: photo.file.path,
              cacheWidth: (size * 3).round(),
            ),
          ),
          if (busy)
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x80000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (remove != null)
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                container: true,
                button: true,
                label: 'Remove this photo',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: remove,
                  // 32 tap area on a 22 badge, inside a 76 tile.
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xCC0A0F0D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.x,
                        size: 14,
                        color: Colors.white,
                      ),
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

/// The cafe the photos go to. A chevron row when it can change; a plain row
/// when it is fixed.
class _CafeRow extends StatelessWidget {
  const _CafeRow({required this.cafe, this.onChange});

  final PickedCafe cafe;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final area = cafe.area;
    final row = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: ListsTokens.border),
        borderRadius: BorderRadius.circular(ListsTokens.radius),
      ),
      child: Row(
        children: [
          ListsThumb(imageUrl: cafe.imageUrl, size: 40, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cafe.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: listsText(14, weight: FontWeight.w500),
                ),
                if (area != null)
                  Text(
                    area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listsText(12, color: ListsTokens.muted),
                  ),
              ],
            ),
          ),
          if (onChange != null) ...[
            Text(
              'Change',
              style: listsText(
                13,
                weight: FontWeight.w500,
                color: ListsTokens.brand,
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: ListsTokens.brand,
            ),
          ],
        ],
      ),
    );
    if (onChange == null) {
      return Semantics(
        label: 'Cafe: ${cafe.name}',
        excludeSemantics: true,
        child: row,
      );
    }
    return Semantics(
      button: true,
      label: 'Cafe: ${cafe.name}. Change',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onChange,
        borderRadius: BorderRadius.circular(ListsTokens.radius),
        child: row,
      ),
    );
  }
}
