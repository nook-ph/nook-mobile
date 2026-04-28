import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/profile/presentation/widgets/favorite_card.dart';

class ListDetailPage extends StatelessWidget {
  final String title;

  const ListDetailPage({super.key, required this.title});

  // Mock data for now
  static final List<CafeSummary> _mockCafes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_mockCafes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Center(
                child: Text(
                  'No cafes in this list yet.',
                  style: TextStyle(fontSize: 15, color: Colors.black38),
                ),
              ),
            )
          else
            ...\_mockCafes.map((cafe) => ListCard(cafe: cafe)),
        ],
      ),
    );
  }
}
