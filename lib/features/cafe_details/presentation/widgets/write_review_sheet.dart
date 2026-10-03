import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/preferences/review_draft_store.dart';
import 'package:nook/core/utils/compressed_image_target.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/content_filter.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_event.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_logic.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Write a review, in two steps inside one sheet: one question and five
/// stars first, then the sheet grows for the text and photos once a star is
/// tapped.
class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({
    super.key,
    required this.cafeId,
    this.cafeName,
    this.cafeImageUrl,
    this.reviewsBloc,
    this.initialText,
  });

  final String cafeId;

  /// Text to start from when there is no draft: the note from the person's
  /// own ranking, so posting it is not writing it twice.
  final String? initialText;
  final String? cafeName;
  final String? cafeImageUrl;

  /// The cafe's loaded reviews, used to tell whether the user already
  /// reviewed it. The sheet lives in its own route, so it is passed in.
  final ReviewsBloc? reviewsBloc;

  static Future<void> show(
    BuildContext context, {
    required String cafeId,
    String? cafeName,
    String? cafeImageUrl,
    String? initialText,
  }) async {
    final submitBloc =
        context.read<ReviewSubmitBloc?>() ?? sl<ReviewSubmitBloc>();
    final reviewsBloc = context.read<ReviewsBloc?>();
    final detailsState = context.read<CafeDetailsBloc?>()?.state;
    final cafe = detailsState is CafeDetailsLoaded
        ? detailsState.data.cafeDetails
        : null;

    await ReviewSheetShell.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: submitBloc,
        child: WriteReviewSheet(
          cafeId: cafeId,
          cafeName: cafeName ?? cafe?.name,
          cafeImageUrl: cafeImageUrl ?? cafe?.featuredImageUrl,
          reviewsBloc: reviewsBloc,
          initialText: initialText,
        ),
      ),
    );
    if (submitBloc.state is! ReviewSubmitting) return;
    // Swiped away mid-submit: the sheet is gone, the request is not. The
    // draft is cleared either way; the toast needs the page to still be up.
    unawaited(() async {
      final message = await _lateOutcome(submitBloc, cafeId);
      if (message == null || !context.mounted) return;
      showPrimaryToast(context, message);
    }());
  }

  /// Finishes a submit whose sheet was dismissed before it resolved: on
  /// success clears the draft the dismissal just saved, so the posted review
  /// does not come back as one. Returns what to tell the user, if anything.
  static Future<String?> _lateOutcome(
    ReviewSubmitBloc submitBloc,
    String cafeId,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final outcome = await submitBloc.stream.firstWhere(
      (state) => state is ReviewSubmitSuccess || state is ReviewSubmitError,
      orElse: () => submitBloc.state,
    );
    if (outcome is ReviewSubmitSuccess) {
      await sl<ReviewDraftStore>().clear(cafeId, userId: userId);
      return 'Review posted';
    }
    return outcome is ReviewSubmitError ? outcome.message : null;
  }

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

enum _DraftNote { none, saved, recovered }

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  static const int _maxPhotos = 3;

  int _rating = 0;

  /// False until a star is tapped (or a draft is recovered): the sheet shows
  /// only the question and the stars.
  bool _composing = false;
  late final TextEditingController _reviewController;
  final List<File> _photos = <File>[];
  final ImagePicker _imagePicker = ImagePicker();
  final ReviewDraftStore _draftStore = sl<ReviewDraftStore>();
  AppLifecycleListener? _appLifecycleListener;

  _DraftNote _draftNote = _DraftNote.none;

  /// When the recovered draft was last saved, for the banner.
  DateTime? _recoveredAt;
  Timer? _draftDebounce;
  Future<void>? _saveInFlight;

  /// Set the moment a submit succeeds. Nothing may save a draft after this,
  /// or the review that was just posted would come back as a draft.
  bool _submitted = false;

  /// The last submit's failure, shown in the sheet until the next edit.
  String? _submitError;
  String? _textError;
  String? _username;

  /// "You ranked it 7.0 · #3 of 5 (private)", or null when not ranked.
  String? _rankingLine(BuildContext context) {
    final rankings = context.read<CafeRankingCubit?>()?.state.rankings;
    if (rankings == null) return null;
    final index = rankings.indexWhere((r) => r.cafeId == widget.cafeId);
    if (index < 0) return null;
    return 'You ranked it ${rankings[index].displayScore} · '
        '#${index + 1} of ${rankings.length} (private)';
  }

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController();
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycle,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDraft();
    });
    _loadUsername();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _appLifecycleListener?.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();
      final username = (row?['username'] as String?)?.trim();
      if (!mounted || username == null || username.isEmpty) return;
      setState(() => _username = username);
    } catch (_) {
      // The line is informative only; leave it out when it cannot load.
    }
  }

  /// Whose draft this is. Drafts are kept per account, so a second person
  /// signing in on the same phone starts from an empty sheet.
  String? get _draftUserId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _saveDraft() async {
    if (_submitted) return;
    if (_reviewController.text.trim().isEmpty && _rating == 0) return;
    // One save at a time; a newer one waits for the one in flight.
    await _saveInFlight;
    if (_submitted) return;
    final save = _draftStore.save(
      widget.cafeId,
      text: _reviewController.text,
      rating: _rating,
      userId: _draftUserId,
    );
    _saveInFlight = save;
    try {
      await save;
    } finally {
      if (identical(_saveInFlight, save)) _saveInFlight = null;
    }
    if (mounted && !_submitted) {
      setState(() => _draftNote = _DraftNote.saved);
    }
  }

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 800), _saveDraft);
  }

  Future<void> _loadDraft() async {
    final draft = await _draftStore.load(widget.cafeId, userId: _draftUserId);
    if (!mounted || _composing) return;
    if (draft == null) {
      final start = widget.initialText?.trim() ?? '';
      if (start.isNotEmpty && _reviewController.text.isEmpty) {
        _reviewController.text = start;
      }
      return;
    }
    if (draft.text.trim().isEmpty && draft.rating == 0) return;

    _reviewController.value = TextEditingValue(
      text: draft.text,
      selection: TextSelection.collapsed(offset: draft.text.length),
    );
    setState(() {
      _rating = draft.rating;
      _composing = true;
      _draftNote = _DraftNote.recovered;
      _recoveredAt = draft.updatedAt;
    });
  }

  /// "Start over" on the recovered-draft banner: throws the draft away and
  /// goes back to the first step.
  Future<void> _startOver() async {
    _draftDebounce?.cancel();
    try {
      await _saveInFlight;
    } catch (_) {
      // The clear below is what matters.
    }
    await _draftStore.clear(widget.cafeId, userId: _draftUserId);
    if (!mounted) return;
    _reviewController.clear();
    setState(() {
      _rating = 0;
      _photos.clear();
      _composing = false;
      _draftNote = _DraftNote.none;
      _recoveredAt = null;
      _submitError = null;
      _textError = null;
    });
  }

  void _handleAppLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _draftDebounce?.cancel();
      _saveDraft();
    }
  }

  /// A posted review must not survive as a draft: stop pending saves, let
  /// any save already running finish, then clear, and only then close.
  Future<void> _finishSubmitted() async {
    _submitted = true;
    _draftDebounce?.cancel();
    try {
      await _saveInFlight;
    } catch (_) {
      // The clear below is what matters.
    }
    await _draftStore.clear(widget.cafeId, userId: _draftUserId);
    if (!mounted) return;
    showPrimaryToast(context, 'Review posted');
    Navigator.of(context).pop();
  }

  Future<File> _compressImage(File file) async {
    final filePath = file.path;
    final target = compressedImageTarget(filePath);

    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      target.path,
      quality: 75,
      minWidth: 1280,
      minHeight: 1280,
      format: target.isPng ? CompressFormat.png : CompressFormat.jpeg,
    );

    if (result == null) return file;
    return File(result.path);
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) return;

    final File file;
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      file = await _compressImage(File(picked.path));
    } catch (e) {
      // Denied photo access, an unreadable file or a failed compress.
      debugPrint('[WriteReview] pick photo failed: $e');
      if (!mounted) return;
      setState(
        () => _submitError = 'Could not add that photo. Please try another.',
      );
      return;
    }
    if (!mounted || _photos.length >= _maxPhotos) return;
    setState(() {
      _photos.add(file);
      _submitError = null;
    });
  }

  void _setRating(int rating) {
    setState(() {
      _rating = rating;
      _composing = true;
      _submitError = null;
    });
    _scheduleDraftSave();
  }

  void _onTextChanged(String _) {
    if (_submitError != null || _textError != null) {
      setState(() {
        _submitError = null;
        _textError = null;
      });
    }
    _scheduleDraftSave();
  }

  static String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Terrible';
      case 2:
        return 'Bad';
      case 3:
        return 'Okay';
      case 4:
        return 'Great';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Future<void> _submitReview() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_rating == 0) return;

    if (ContentFilter.containsObjectionable(_reviewController.text)) {
      setState(() => _textError = ContentFilter.rejectionMessage);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.of(context).pop();
      context.push('/login');
      return;
    }

    final reviewsState = widget.reviewsBloc?.state;
    if (reviewsState is ReviewsLoaded &&
        reviewsState.reviews.any((review) => review.userId == user.id)) {
      setState(
        () => _submitError = 'You already submitted a review for this cafe.',
      );
      return;
    }

    setState(() => _submitError = null);
    final submitBloc = context.read<ReviewSubmitBloc>();

    String? accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      try {
        final refreshed = await Supabase.instance.client.auth.refreshSession();
        accessToken = refreshed.session?.accessToken;
      } catch (_) {
        // Continue; submit will handle unauthenticated state gracefully.
      }
    }

    submitBloc.add(
      SubmitReviewRequested(
        cafeId: widget.cafeId,
        userId: user.id,
        rating: _rating,
        content: _reviewController.text,
        photos: List<File>.unmodifiable(_photos),
        accessToken: accessToken,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReviewSubmitBloc, ReviewSubmitState>(
      listener: (context, state) {
        if (state is ReviewSubmitSuccess) {
          unawaited(_finishSubmitted());
        }
        if (state is ReviewSubmitError) {
          setState(() => _submitError = state.message);
        }
      },
      builder: (context, state) {
        final isSubmitting = state is ReviewSubmitting;

        return PopScope(
          // Back and the scrim wait for the submit; a drag still gets
          // through, which is what [_reportLateOutcome] is for.
          canPop: !isSubmitting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) return;
            _draftDebounce?.cancel();
            unawaited(_saveDraft());
          },
          child: ReviewSheetShell(
            title: _composing ? 'Your review' : null,
            onClose: () => Navigator.of(context).maybePop(),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: _composing
                  ? _compose(context, isSubmitting)
                  : _rate(context),
            ),
          ),
        );
      },
    );
  }

  Widget _rate(BuildContext context) {
    final name = widget.cafeName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CafeThumb(imageUrl: widget.cafeImageUrl, size: 64),
          if (name != null && name.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              name,
              style: context.textTheme.bodySmall?.copyWith(
                color: ReviewTokens.muted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'How was your visit?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ReviewTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          _StarInput(rating: _rating, size: 36, onChanged: _setRating),
          const SizedBox(height: 4),
          Text(
            'Tap a star to rate',
            style: context.textTheme.bodySmall?.copyWith(
              color: ReviewTokens.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compose(BuildContext context, bool isSubmitting) {
    final name = widget.cafeName;
    final username = _username;
    final submitError = _submitError;
    final textError = _textError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _CafeThumb(imageUrl: widget.cafeImageUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (name != null && name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMediumMed.copyWith(
                        color: ReviewTokens.ink,
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    username == null
                        ? 'Posting publicly'
                        : 'Posting publicly as $username',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: ReviewTokens.muted,
                    ),
                  ),
                  // The private ranking beside the public review, so the two
                  // ratings of one visit are seen together
                  // (docs/ux/core-loops.md, finding 2).
                  if (_rankingLine(context) case final line?)
                    Text(
                      line,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: ReviewTokens.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (submitError != null) ...[
          const SizedBox(height: 14),
          _Banner(
            color: ReviewTokens.danger.withValues(alpha: 0.08),
            child: Text(
              submitError,
              style: context.textTheme.bodySmall?.copyWith(
                color: ReviewTokens.danger,
                fontSize: 12,
              ),
            ),
          ),
        ] else if (_draftNote == _DraftNote.recovered) ...[
          const SizedBox(height: 14),
          _Banner(
            color: ReviewTokens.tint,
            action: isSubmitting ? null : _startOver,
            actionLabel: 'Start over',
            child: Text(
              draftRecoveredLabel(_recoveredAt),
              style: context.textTheme.bodySmall?.copyWith(
                color: ReviewTokens.ink,
                fontSize: 12,
              ),
            ),
          ),
        ],
        // The stars are 44pt targets around 30pt glyphs, which supplies the
        // rest of the 14 gap above and below.
        const SizedBox(height: 7),
        Row(
          children: [
            _StarInput(
              rating: _rating,
              size: 30,
              onChanged: isSubmitting ? null : _setRating,
            ),
            if (_rating != 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _ratingLabel(_rating),
                  style: context.textTheme.bodyMediumMed.copyWith(
                    color: ReviewTokens.brand,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (_rating == 0) ...[
          Text(
            'Pick a star rating to post your review',
            style: context.textTheme.bodySmall?.copyWith(
              color: ReviewTokens.danger,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 7),
        TextField(
          controller: _reviewController,
          maxLines: 6,
          minLines: 6,
          enabled: !isSubmitting,
          onChanged: _onTextChanged,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: ReviewTokens.brand,
          style: context.textTheme.bodyMedium?.copyWith(
            color: ReviewTokens.ink,
            fontSize: 14,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText:
                'Tell us about the atmosphere, the coffee, and the service...',
            hintStyle: context.textTheme.bodyMedium?.copyWith(
              color: ReviewTokens.muted,
              fontSize: 14,
            ),
            filled: true,
            fillColor: ReviewTokens.surface,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: _fieldBorder(
              textError == null ? ReviewTokens.border : ReviewTokens.danger,
              textError == null ? 1 : 1.5,
            ),
            disabledBorder: _fieldBorder(ReviewTokens.border, 1),
            focusedBorder: _fieldBorder(
              textError == null ? ReviewTokens.ink : ReviewTokens.danger,
              1.5,
            ),
          ),
        ),
        if (textError != null) ...[
          const SizedBox(height: 6),
          _InlineError(message: textError),
        ],
        if (_draftNote == _DraftNote.saved) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check, size: 14, color: ReviewTokens.muted),
              const SizedBox(width: 6),
              Text(
                'Draft saved',
                style: context.textTheme.bodySmall?.copyWith(
                  color: ReviewTokens.muted,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'Photos',
              style: context.textTheme.bodyMediumMed.copyWith(
                color: ReviewTokens.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              photoCountLabel(_photos.length, _maxPhotos),
              style: context.textTheme.bodySmall?.copyWith(
                color: ReviewTokens.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final photo in _photos) ...[
              _PhotoThumbnail(
                file: photo,
                onRemove: isSubmitting
                    ? null
                    : () => setState(() {
                        _photos.remove(photo);
                        _submitError = null;
                      }),
              ),
              const SizedBox(width: 10),
            ],
            if (_photos.length < _maxPhotos)
              _AddPhotoButton(onTap: isSubmitting ? null : _pickPhoto),
          ],
        ),
        const SizedBox(height: 14),
        ReviewPrimaryButton(
          label: submitError == null ? 'Submit review' : 'Try again',
          busy: isSubmitting,
          busyLabel: 'Posting…',
          onTap: _rating == 0 ? null : _submitReview,
        ),
      ],
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// A tinted line under the cafe row: the submit error, or the recovered
/// draft with its "Start over".
class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.child,
    this.action,
    this.actionLabel,
  });

  final Color color;
  final Widget child;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 0, label == null ? 12 : 2, 0),
      constraints: const BoxConstraints(minHeight: 42),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: child,
            ),
          ),
          if (label != null)
            AdaptiveTap(
              onTap: action,
              borderRadius: BorderRadius.circular(12),
              child: Semantics(
                button: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 42),
                  child: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        label,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: ReviewTokens.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.error_outline,
            size: 14,
            color: ReviewTokens.danger,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: context.textTheme.bodySmall?.copyWith(
              color: ReviewTokens.danger,
            ),
          ),
        ),
      ],
    );
  }
}

/// Five tappable stars. Each is a 44pt target regardless of [size].
class _StarInput extends StatelessWidget {
  const _StarInput({
    required this.rating,
    required this.size,
    required this.onChanged,
  });

  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          AdaptiveTap(
            onTap: change == null ? null : () => change(star),
            borderRadius: BorderRadius.circular(22),
            child: Semantics(
              button: true,
              selected: star <= rating,
              label: star == 1 ? '1 star' : '$star stars',
              excludeSemantics: true,
              child: SizedBox(
                width: size + 8,
                height: 44,
                child: Icon(
                  star <= rating ? Icons.star : Icons.star_border,
                  size: size,
                  color: star <= rating
                      ? ReviewTokens.star
                      : const Color(0xFFC4C4C4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CafeThumb extends StatelessWidget {
  const _CafeThumb({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFDAD7CD),
      alignment: Alignment.center,
      child: Icon(
        Icons.local_cafe_outlined,
        size: size * 0.45,
        color: ReviewTokens.brand,
      ),
    );
    final url = imageUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: url.isEmpty
            ? fallback
            : CafeCardImage(imageUrl: url, errorWidget: fallback),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.file, this.onRemove});

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 80,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Semantics(
                button: true,
                label: 'Remove photo',
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
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

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Semantics(
        button: true,
        label: 'Add photo',
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: 80,
          child: CustomPaint(
            painter: const _DashedBorderPainter(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 18, color: ReviewTokens.mutedIcon),
                const SizedBox(height: 2),
                Text(
                  'Add',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: ReviewTokens.muted,
                    fontSize: 10,
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFC4C4C4);
    const strokeWidth = 1.5;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    const radius = 12.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            strokeWidth / 2,
            strokeWidth / 2,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          const Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
