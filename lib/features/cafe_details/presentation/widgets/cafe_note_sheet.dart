import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_note_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_note_usecase.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

/// One-field private note on a logged cafe — the journal garnish after a
/// one-tap log (spec: docs/BEEN_WANT_TO_TRY.md §3.1). Never blocks logging:
/// it is always opened *after* the status write has already succeeded.
Future<void> showCafeNoteSheet(
  BuildContext context, {
  required String cafeId,
  required String cafeName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CafeNoteSheet(cafeId: cafeId, cafeName: cafeName),
  );
}

class _CafeNoteSheet extends StatefulWidget {
  const _CafeNoteSheet({required this.cafeId, required this.cafeName});

  final String cafeId;
  final String cafeName;

  @override
  State<_CafeNoteSheet> createState() => _CafeNoteSheetState();
}

class _CafeNoteSheetState extends State<_CafeNoteSheet> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingNote();
  }

  @override
  void dispose() {
    _controller.dispose();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await sl<SetCafeNoteUseCase>()(widget.cafeId, _controller.text);
      if (!mounted) return;
      Navigator.pop(context);
      showPrimaryToast(
        context,
        _controller.text.trim().isEmpty ? 'Note cleared' : 'Note saved',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final info = AppErrorCopy.fromException(e);
      showPrimaryToast(context, '${info.title} · ${info.subtitle}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your note',
                    style: Theme.of(context).textTheme.titleMediumSemi,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Private to you · ${widget.cafeName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF868584),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    enabled: !_isLoading,
                    autofocus: !_isLoading,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isLoading
                          ? 'Loading…'
                          : 'What do you want to remember about this place?',
                      hintStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: const Color(0xFFB0AFAE)),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3A5A40)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: AdaptiveElevatedButton(
                      onPressed: _isLoading || _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3A5A40),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFB6C2B8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        _isSaving ? 'Saving…' : 'Save note',
                        style: Theme.of(context).textTheme.bodyLargeMed
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
