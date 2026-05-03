import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/features/search/presentation/widgets/best_for_tag_list.dart';
import 'package:nook/features/search/presentation/widgets/amenities_tag_list.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class SearchResultsPage extends StatelessWidget {
  const SearchResultsPage({super.key, required this.query});

  final String query;

  static const List<Map<String, String>> _placeholderResults = [
    {'name': 'Cafe Name', 'location': 'Location, Cebu', 'distance': '1.2 km'},
    {'name': 'Cafe Name', 'location': 'Location, Cebu', 'distance': '2.4 km'},
    {'name': 'Cafe Name', 'location': 'Location, Cebu', 'distance': '0.8 km'},
    {'name': 'Cafe Name', 'location': 'Location, Cebu', 'distance': '3.1 km'},
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final borderColor = Theme.of(context).colorScheme.border;
    final controller = TextEditingController(text: query);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1.5),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Search cafes...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(
                        PhosphorIcons.magnifyingGlass(),
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: textTheme.bodyLarge?.copyWith(color: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),
                const BestForTagList(),
                const SizedBox(height: 20),
                const AmenitiesTagList(),
                const SizedBox(height: 20),
                Text(
                  'Cafes',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                ListView.builder(
                  itemCount: _placeholderResults.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final item = _placeholderResults[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item['name'] ?? '',
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['location'] ?? '',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item['distance'] ?? '',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
