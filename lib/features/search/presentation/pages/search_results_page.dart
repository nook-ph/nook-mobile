import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/widgets/error/location_denied_banner.dart';
import 'package:nook/core/widgets/error/section_empty_widget.dart';
import 'package:nook/features/search/bloc/search_bloc.dart';
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
  late final FocusNode _searchFocusNode;
  late final SearchBloc _searchBloc;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchFocusNode = FocusNode();
    _searchBloc = sl<SearchBloc>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _searchFocusNode.requestFocus();
      });
    });

    if (widget.query.isNotEmpty) {
      _searchBloc.add(SearchQueryChanged(widget.query));
    } else {
      _searchBloc.add(const SearchRefresh());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchBloc.close();
    super.dispose();
  }

  Future<void> _onRefresh(BuildContext context) async {
    _searchBloc.add(const SearchRefresh());
    await _searchBloc.stream.firstWhere(
      (s) => s.status != SearchStatus.loading,
    );
    await Future<void>.delayed(Duration.zero);
  }

  void _retryOrSignIn(BuildContext context, SearchState blocState) {
    final raw = blocState.lastError ?? Exception('Search failed');
    final info = AppErrorCopy.fromException(raw);
    if (info.type == ErrorType.sessionExpired) {
      context.push('/login');
      return;
    }
    _searchBloc.add(const SearchRefresh());
  }

  void _onScroll() {
    if (_isBottom) _searchBloc.add(const SearchLoadMore());
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

              final results = state.cafes
                  .map(
                    (cafe) => {
                      'name': cafe.name,
                      'location': cafe.locationLabel,
                      'distance': _formatDistance(cafe.distanceMeters),
                      'image': cafe.coverImage,
                    },
                  )
                  .toList();

              final showLocBanner =
                  state.locationDenied && !state.locationBannerDismissed;

              return RefreshIndicator(
                onRefresh: () => _onRefresh(context),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Search bar row with back button ──
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  autofocus: true,
                                  onChanged: (value) {
                                    _searchBloc.add(SearchQueryChanged(value));
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search cafes...',
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                    ),
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
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (showLocBanner)
                          LocationDeniedBanner(
                            visible: true,
                            onDismiss: () => _searchBloc.add(
                              const SearchDismissLocationBanner(),
                            ),
                          ),

                        const SizedBox(height: 20),

                        if (hasError)
                          SizedBox(
                            height: 420,
                            child: FullPageErrorWidget(
                              error: AppErrorCopy.fromException(
                                state.lastError ?? Exception('Search failed'),
                              ),
                              onRetry: () => _retryOrSignIn(context, state),
                            ),
                          )
                        else if (isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: SectionEmptyWidget(
                              title: 'No cafes found',
                              subtitle: 'Try another search or adjust filters.',
                              icon: Icons.search_off_outlined,
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            image: item['image'] != null
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      item['image']!,
                                                    ),
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
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          Colors.grey.shade500,
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

  Widget _buildHighlightedText(TextTheme textTheme, String text, String query) {
    final trimmed = query.trim();
    final baseStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );
    final highlightStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w700,
      backgroundColor: Colors.black12,
    );

    if (trimmed.isEmpty) return Text(text, style: baseStyle);

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmed.toLowerCase();
    if (!lowerText.contains(lowerQuery)) return Text(text, style: baseStyle);

    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
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
