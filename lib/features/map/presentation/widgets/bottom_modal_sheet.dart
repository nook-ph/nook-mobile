import 'package:flutter/material.dart';
import 'package:nook/features/map/presentation/widgets/cafe_card.dart';

class BottomModalSheet extends StatefulWidget {
  const BottomModalSheet({super.key});

  @override
  State<BottomModalSheet> createState() => _BottomModalSheetState();
}

class _BottomModalSheetState extends State<BottomModalSheet> {
  final List<Map<String, dynamic>> _cafes = [
    {
      "name": "Mellow Mug",
      "address": "45 Mango Street, Cebu City",
      "rating": 4.6,
      "tag": "Cozy Corner",
      "distance": "2.1 km",
      "cafeId": "cafe-101",
      "imageUrl": "https://picsum.photos/200/300?grayscale",
    },
    {
      "name": "Latte Lane",
      "address": "78 Oak Avenue, Cebu City",
      "rating": 4.7,
      "tag": "Study Friendly",
      "distance": "3.5 km",
      "cafeId": "cafe-102",
      "imageUrl": "https://picsum.photos/200/300?grayscale",
    },
    {
      "name": "Brewtopia",
      "address": "12 Pine Street, Cebu City",
      "rating": 4.0,
      "tag": "Pet Friendly",
      "distance": "1.8 km",
      "cafeId": "cafe-103",
      "imageUrl": "https://picsum.photos/200/300?grayscale",
    },
    {
      "name": "The Coffee Nook",
      "address": "23 Elm Road, Cebu City",
      "rating": 4.8,
      "tag": "Instagrammable",
      "distance": "4.2 km",
      "cafeId": "cafe-104",
      "imageUrl": "https://picsum.photos/200/300?grayscale",
    },
    {
      "name": "Café Aroma",
      "address": "90 Cherry Lane, Cebu City",
      "rating": 4.4,
      "tag": "Quiet Spot",
      "distance": "2.9 km",
      "cafeId": "cafe-105",
      "imageUrl": "https://picsum.photos/200/300?grayscale",
    },
    {
      "name": "Espresso Escape",
      "address": "33 Maple Boulevard, Cebu City",
      "rating": 4.6,
      "tag": "Cozy Corner",
      "distance": "3.8 km",
      "cafeId": "cafe-106",
      "imageUrl": "https://picsum.photos/200/300?grayscale",
    },
    {
      "name": "Perk & Sip",
      "address": "56 Walnut Street, Cebu City",
      "rating": 4.5,
      "tag": "Study Friendly",
      "distance": "1.5 km",
      "cafeId": "cafe-107",
      "imageUrl": "https://picsum.photos/200/300?grayscale",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.06,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.06, 0.85],
      snapAnimationDuration: const Duration(milliseconds: 100),
      builder: (BuildContext context, ScrollController scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 48,
                  ),
                  itemCount: _cafes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 36),
                  itemBuilder: (BuildContext context, int index) {
                    final cafe = _cafes[index];
                    return CafeCard(
                      name: cafe['name']!,
                      address: cafe['address']!,
                      rating: (cafe['rating'] as num).toDouble(),
                      tag: cafe['tag']!,
                      distance: cafe['distance']!,
                      cafeId: cafe['cafeId']!,
                      imageUrl: cafe['imageUrl']!,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
