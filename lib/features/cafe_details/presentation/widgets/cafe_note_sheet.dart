import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_note_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_note_usecase.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/injection_container.dart';

/// Longest private note a cafe can carry.
const cafeNoteLimit = 500;

/// One-field private note on a logged cafe — the journal garnish after a
/// one-tap log (spec: docs/BEEN_WANT_TO_TRY.md §3.1; Figma "Note — empty",
/// "Note — edit"). Never blocks logging: it is always opened *after* the
/// status write has already succeeded.
///
/// [bottomOffset] lifts the result toast above a sticky bottom bar.
Future<void> showCafeNoteSheet(
  BuildContext context, {
  required String cafeId,
  required String cafeName,
  double bottomOffset = 0,
}) {
  return ListsSheet.show<void>(
    context,
    builder: (_) => CafeNoteSheet(
      cafeId: cafeId,
      cafeName: cafeName,
      toastContext: context,
      bottomOffset: bottomOffset,
    ),
  );
}

/// The sheet body. Public so it can be pumped in tests; open it with
/// [showCafeNoteSheet].
class CafeNoteSheet extends StatefulWidget {
  const CafeNoteSheet({
    super.key,
    required this.cafeId,
    required this.cafeName,
    this.toastContext,
    this.bottomOffset = 0,
  });

  final String cafeId;
  final String cafeName;

  /// The page under the sheet. "Note saved" is shown from there, because the
  /// sheet's own context is gone once it has popped.
  final BuildContext? toastContext;
  final double bottomOffset;

  @override
  State<CafeNoteSheet> createState() => _CafeNoteSheetState();
}

class _CafeNoteSheetState extends State<CafeNoteSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _loadExistingNote();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadExistingNote() async {
    try {
      final note = await sl<GetCafeNoteUseCase>()(widget.cafeId);
      if (!mounted) return;
      _controller.text = note ?? '';
    } catch (_) {
      // Prefill is best-effort — an empty field is still usable.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        // The field is disabled while the note loads, so it can only take
        // focus once it is enabled again.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await sl<SetCafeNoteUseCase>()(widget.cafeId, _controller.text);
      if (!mounted) return;
      final cleared = _controller.text.trim().isEmpty;
      final host = widget.toastContext;
      Navigator.pop(context);
      if (host != null && host.mounted) {
        showPrimaryToast(
          host,
          cleared ? 'Note cleared' : 'Note saved',
          bottomOffset: widget.bottomOffset,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final info = AppErrorCopy.fromException(e);
      showPrimaryToast(context, '${info.title} · ${info.subtitle}');
    }
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      borderSide: BorderSide(color: color, width: width),
    );

    return ListsSheet(
      title: 'Your note',
      gap: 12,
      children: [
        Text(
          'Private to you · ${widget.cafeName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: listsText(12, color: ListsTokens.muted),
        ),
        SizedBox(
          height: 140,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: !_isLoading,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(cafeNoteLimit)],
            cursorColor: ListsTokens.brand,
            style: listsText(14),
            decoration: InputDecoration(
              hintText: _isLoading
                  ? 'Loading…'
                  : 'What do you want to remember about this place?',
              hintStyle: listsText(14, color: ListsTokens.muted),
              hintMaxLines: 3,
              isDense: true,
              filled: true,
              fillColor: ListsTokens.surface,
              contentPadding: const EdgeInsets.all(14),
              disabledBorder: border(ListsTokens.border, 1),
              enabledBorder: border(ListsTokens.border, 1),
              focusedBorder: border(ListsTokens.brand, 1.5),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_controller.text.characters.length} / $cafeNoteLimit',
            style: listsText(12, color: ListsTokens.muted),
          ),
        ),
        ListsPillButton(
          label: 'Save note',
          onTap: _isLoading ? null : _save,
          busy: _isSaving,
        ),
      ],
    );
  }
}
