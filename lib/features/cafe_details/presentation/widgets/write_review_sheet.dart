import 'dart:async';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_event.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/core/preferences/review_draft_store.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/core/utils/content_filter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({super.key, required this.cafeId});

  final String cafeId;

  static Future<void> show(BuildContext context, {required String cafeId}) {
    final submitBloc =
        context.read<ReviewSubmitBloc?>() ?? sl<ReviewSubmitBloc>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider.value(
        value: submitBloc,
        child: WriteReviewSheet(cafeId: cafeId),
      ),
    );
  }

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  int _selectedRating = 0;
  late final TextEditingController _reviewController;
  final List<File?> _photos = <File?>[null, null, null];
  final ImagePicker _imagePicker = ImagePicker();
  final ReviewDraftStore _draftStore = sl<ReviewDraftStore>();
  AppLifecycleListener? _appLifecycleListener;
  bool _isSavingDraft = false;
  bool _recoveredDraft = false;

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
  }

  @override
  void didUpdateWidget(covariant WriteReviewSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafeId != widget.cafeId) {
      _reviewController.clear();
      setState(() {
        _selectedRating = 0;
        _recoveredDraft = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDraft();
      });
    }
  }

  @override
  void dispose() {
    _appLifecycleListener?.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft({bool showToast = false}) async {
    if (_isSavingDraft) return;
    if (_reviewController.text.trim().isEmpty && _selectedRating == 0) return;
    _isSavingDraft = true;
    try {
      await _draftStore.save(
        widget.cafeId,
        text: _reviewController.text,
        rating: _selectedRating,
      );
      if (showToast && mounted) {
        showPrimaryToast(context, 'Draft saved');
      }
    } finally {
      _isSavingDraft = false;
    }
  }

  Future<void> _loadDraft() async {
    final draft = await _draftStore.load(widget.cafeId);
    if (!mounted || draft == null) return;
    if (_recoveredDraft) return;

    _reviewController.value = TextEditingValue(
      text: draft.text,
      selection: TextSelection.collapsed(offset: draft.text.length),
    );
    setState(() {
      _selectedRating = draft.rating;
      _recoveredDraft = true;
    });
    showPrimaryToast(context, 'Draft recovered');
  }

  void _handleAppLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _saveDraft(showToast: true);
    }
  }

  Future<File> _compressImage(File file) async {
    final filePath = file.path;
    final ext = filePath.split('.').last.toLowerCase();
    final targetPath = filePath.replaceAll('.$ext', '_compressed.$ext');

    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      targetPath,
      quality: 75,
      minWidth: 1280,
      minHeight: 1280,
      format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
    );

    if (result == null) return file;
    return File(result.path);
  }

  Future<void> _pickPhoto() async {
    final nextIndex = _photos.indexWhere((f) => f == null);
    if (nextIndex == -1) return;

    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null) return;

    final file = await _compressImage(File(picked.path));

    setState(() {
      _photos[nextIndex] = file;
    });
  }

  Widget _buildPhotosRow(bool isSubmitting) {
    final filled = _photos.whereType<File>().toList();
    final showAddButton = filled.length < 3;

    final items = <Widget>[
      for (int i = 0; i < filled.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: _PhotoThumbnail(
            file: filled[i],
            onRemove: isSubmitting
                ? null
                : () {
                    setState(() {
                      final indexToRemove = _photos.indexOf(filled[i]);
                      if (indexToRemove != -1) {
                        _photos[indexToRemove] = null;
                      }
                    });
                  },
          ),
        ),
      ],
      if (showAddButton) ...[
        if (filled.isNotEmpty) const SizedBox(width: 10),
        Expanded(
          child: _AddPhotoButton(onTap: isSubmitting ? null : _pickPhoto),
        ),
      ],
      // Fill remaining space with invisible expanded slots so items always
      // take equal widths regardless of how many are shown.
      for (int i = filled.length + (showAddButton ? 1 : 0); i < 3; i++) ...[
        const SizedBox(width: 10),
        const Expanded(child: SizedBox.shrink()),
      ],
    ];

    return Row(children: items);
  }

  String _ratingLabel(int rating) {
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

  Future<void> _submitReview(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_selectedRating == 0) {
      showPrimaryToast(context, 'Please select a rating before submitting.');
      return;
    }

    if (ContentFilter.containsObjectionable(_reviewController.text)) {
      showPrimaryToast(context, ContentFilter.rejectionMessage);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        Navigator.of(context).pop();
        context.push('/login');
      }
      return;
    }

    final reviewsBloc = context.read<ReviewsBloc?>();
    if (reviewsBloc != null) {
      final reviewsState = reviewsBloc.state;
      if (reviewsState is ReviewsLoaded) {
        final hasAlreadyReviewed = reviewsState.reviews.any(
          (review) => review.userId == user.id,
        );

        if (hasAlreadyReviewed) {
          showPrimaryToast(
            context,
            'You already submitted a review for this cafe.',
          );
          return;
        }
      }
    }

    final selectedPhotos = _photos.whereType<File>().toList(growable: false);
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
        rating: _selectedRating,
        content: _reviewController.text,
        photos: selectedPhotos,
        accessToken: accessToken,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReviewSubmitBloc, ReviewSubmitState>(
      listener: (context, state) {
        if (state is ReviewSubmitSuccess) {
          unawaited(_draftStore.clear(widget.cafeId));
          Navigator.of(context).pop();
          showPrimaryToast(context, 'Review submitted successfully.');
        }

        if (state is ReviewSubmitError) {
          showPrimaryToast(context, state.message);
        }
      },
      builder: (context, state) {
        final isSubmitting = state is ReviewSubmitting;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) return;
            unawaited(_saveDraft());
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AdaptiveTap(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Colors.black, size: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'How was your visit?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final bool isFilled = index < _selectedRating;
                    return AdaptiveTap(
                      onTap: isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _selectedRating = index + 1;
                              });
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.star_rounded,
                          size: 48,
                          color: isFilled
                              ? const Color(0xFF344E41)
                              : const Color(0xFFCCCCCC),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 22,
                  child: Center(
                    child: _selectedRating == 0
                        ? const SizedBox.shrink()
                        : Text(
                            _ratingLabel(_selectedRating),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Share your experience...',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reviewController,
                  maxLines: 6,
                  minLines: 6,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    hintText:
                        'Tell us about the atmosphere, the coffee, and the service...',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBDBDBD),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add photos (Max 3)',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      'Optional',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPhotosRow(isSubmitting),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: AdaptiveElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () => _submitReview(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF344E41),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Submit Review',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.file, this.onRemove});

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
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
      child: SizedBox(
        // iOS wraps taps in a CupertinoButton whose Align gives the child loose
        // width constraints, so an unconstrained-width child shrink-wraps to its
        // contents. Pin the width to fill the Expanded slot on both platforms.
        width: double.infinity,
        height: 100,
        child: CustomPaint(
          painter: const _DashedBorderPainter(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 22, color: Color(0xFF9E9E9E)),
              const SizedBox(height: 6),
              Text(
                'Add photo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
            ],
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
    const color = Color(0xFFBDBDBD);
    const strokeWidth = 1.5;
    const dashWidth = 6.0;
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
