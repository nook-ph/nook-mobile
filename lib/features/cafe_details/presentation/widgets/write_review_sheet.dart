import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const WriteReviewSheet(),
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

  Future<void> _pickPhoto() async {
    final int targetIndex = _photos.indexWhere((photo) => photo == null, 1);
    if (targetIndex == -1) {
      return;
    }

    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _photos[targetIndex] = File(picked.path);
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

  @override
  Widget build(BuildContext context) {
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
                onPressed: () {
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
                child: InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBDBDBD)),
                    ),
                    child: const Column(
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _PhotoSlot(file: _photos[1])),
              const SizedBox(width: 10),
              Expanded(child: _PhotoSlot(file: _photos[2])),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF344E41),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Row(
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
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.file});

  final File? file;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 100,
          child: Image.file(file!, fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: Color(0xFFBDBDBD)),
      ),
    );
  }
}
