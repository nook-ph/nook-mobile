import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_event.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/injection_container.dart';
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

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
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

  Future<void> _pickPhoto(int targetIndex) async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null) {
      return;
    }

    final file = await _compressImage(File(picked.path));

    setState(() {
      _photos[targetIndex] = file;
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating before submitting.'),
        ),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already submitted a review for this cafe.'),
            ),
          );
          return;
        }
      }
    }

    final selectedPhotos = _photos.whereType<File>().toList(growable: false);

    String? accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      try {
        final refreshed = await Supabase.instance.client.auth.refreshSession();
        accessToken = refreshed.session?.accessToken;
      } catch (_) {
        // Continue; submit will handle unauthenticated state gracefully.
      }
    }

    context.read<ReviewSubmitBloc>().add(
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
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review submitted successfully.')),
          );
        }

        if (state is ReviewSubmitError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isSubmitting = state is ReviewSubmitting;

        return SingleChildScrollView(
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
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: Colors.black, size: 24),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'How was your visit?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final bool isFilled = index < _selectedRating;
                  return IconButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _selectedRating = index + 1;
                            });
                          },
                    iconSize: 48,
                    splashRadius: 28,
                    icon: Icon(
                      Icons.star_rounded,
                      color: isFilled
                          ? const Color(0xFF344E41)
                          : const Color(0xFFCCCCCC),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Share your experience...',
                style: TextStyle(
                  fontSize: 16,
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
                  hintStyle: const TextStyle(
                    color: Color(0xFFBDBDBD),
                    fontSize: 14,
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
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add photos (Max 3)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PhotoSlot(
                      file: _photos[0],
                      onTap: isSubmitting ? null : () => _pickPhoto(0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoSlot(
                      file: _photos[1],
                      onTap: isSubmitting ? null : () => _pickPhoto(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoSlot(
                      file: _photos[2],
                      onTap: isSubmitting ? null : () => _pickPhoto(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () => _submitReview(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF344E41),
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
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Submit Review',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
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
        );
      },
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.file, this.onTap});

  final File? file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: file == null ? const Color(0xFFEEEEEE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBDBDBD)),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(file!, fit: BoxFit.cover),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 24, color: Colors.black),
                  SizedBox(height: 6),
                  Text(
                    'UPLOAD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
