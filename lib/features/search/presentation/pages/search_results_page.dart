import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/search/bloc/search_bloc.dart';
import 'package:nook/features/search/presentation/widgets/best_for_tag_list.dart';
import 'package:nook/features/search/presentation/widgets/amenities_tag_list.dart';
import 'package:nook/injection_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key, required this.query});

  final String query;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final SearchBloc _searchBloc;

  static const List<Map<String, String?>> _placeholderResults = [
    {
      'name': 'Cafe Name',
      'location': 'Location, Cebu',
      'distance': '1.2 km',
      'image': null,
    },
    {
      'name': 'Cafe Name',
      'location': 'Location, Cebu',
      'distance': '2.4 km',
      'image': null,
    },
    {
      'name': 'Cafe Name',
      'location': 'Location, Cebu',
      'distance': '0.8 km',
      'image': null,
    },
    {
      'name': 'Cafe Name',
      'location': 'Location, Cebu',
      'distance': '3.1 km',
      'image': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchBloc = sl<SearchBloc>();

    if (widget.query.isNotEmpty) {
      _searchBloc.add(SearchQueryChanged(widget.query));
    } else {
      _searchBloc.add(const SearchRefresh());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchBloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      _searchBloc.add(const SearchLoadMore());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final borderColor = Theme.of(context).colorScheme.border;

    return BlocProvider.value(
      value: _searchBloc,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) {
                final isLoading =
                  state.status == SearchStatus.loading && state.cafes.isEmpty;
              final hasError =
                  state.status == SearchStatus.failure && state.cafes.isEmpty;
              final isEmpty =
                  state.status == SearchStatus.success && state.cafes.isEmpty;
                final showBestFor = BestForTagList.hasMatches(state.query);
                final showAmenities = AmenitiesTagList.hasMatches(state.query);

              final results = isLoading
                  ? _placeholderResults
                  : state.cafes
                      .map(
                        (cafe) => {
                          'name': cafe.name,
                          'location': cafe.locationLabel,
                          'distance': _formatDistance(cafe.distanceMeters),
                          'image': cafe.coverImage,
                        },
                      )
                      .toList();

              return SingleChildScrollView(
                controller: _scrollController,
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
                          controller: _searchController,
                          onChanged: (value) {
                            _searchBloc.add(SearchQueryChanged(value));
                          },
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
                          style:
                              textTheme.bodyLarge?.copyWith(color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (showBestFor) ...[
                        BestForTagList(filterQuery: state.query),
                        const SizedBox(height: 20),
                      ],
                      if (showAmenities) ...[
                        AmenitiesTagList(filterQuery: state.query),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        'Cafes',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'Failed to load cafes. Pull to refresh or try again.',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      else if (isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'No cafes found',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      else
                        Skeletonizer(
                          enabled: isLoading,
                          effect: const PulseEffect(),
                          child: IgnorePointer(
                            ignoring: isLoading,
                            child: ListView.builder(
                              itemCount: results.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final item = results[index];

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(12),
                                          image: item['image'] != null
                                              ? DecorationImage(
                                                  image: NetworkImage(item['image']!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildHighlightedText(
                                              textTheme,
                                              item['name'] ?? '',
                                              state.query,
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
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '';
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  Widget _buildHighlightedText(
    TextTheme textTheme,
    String text,
    String query,
  ) {
    final trimmed = query.trim();
    final baseStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );
    final highlightStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w700,
      backgroundColor: Colors.black12,
    );

    if (trimmed.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmed.toLowerCase();
    if (!lowerText.contains(lowerQuery)) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + trimmed.length),
          style: highlightStyle,
        ),
      );
      start = index + trimmed.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

