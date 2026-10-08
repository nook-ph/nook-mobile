import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/presentation/cubit/place_search_cubit.dart';
import 'package:nook/features/search/presentation/widgets/place_search_results.dart';
import 'package:nook/features/search/presentation/widgets/search_origin_sheet.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// "Find a place" for the saved-place editor: a field and the same results
/// as the "Search near" sheet. Resolves with the place tapped.
Future<PlaceSuggestion?> showFindPlaceSheet(
  BuildContext context, {
  required IPlaceSearchRepository repository,
  required Future<SearchPlaceIndex> places,
  ({double lat, double lng})? Function()? bias,
}) {
  return showModalBottomSheet<PlaceSuggestion>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => BlocProvider(
      create: (_) =>
          PlaceSearchCubit(repository: repository, places: places, bias: bias),
      child: const FindPlaceSheet(),
    ),
  );
}

class FindPlaceSheet extends StatefulWidget {
  const FindPlaceSheet({super.key});

  @override
  State<FindPlaceSheet> createState() => _FindPlaceSheetState();
}

class _FindPlaceSheetState extends State<FindPlaceSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => context.read<PlaceSearchCubit>().queryChanged(_controller.text),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: SearchTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        // Tall from the start, so the list does not grow under the thumb
        // while results arrive.
        height: sheetMaxHeight(context),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          keyboard > 0 ? 16 : (safe > 26 ? safe + 8 : 34),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            const SizedBox(height: SheetTitleRow.gap),
            const SheetTitleRow(title: 'Find a place'),
            const SizedBox(height: SheetTitleRow.gap),
            PlaceField(
              controller: _controller,
              hint: 'Place, landmark or street',
              autofocus: true,
              onSubmitted: () {
                final first = context
                    .read<PlaceSearchCubit>()
                    .state
                    .results
                    .firstOrNull;
                if (first != null) Navigator.of(context).pop(first);
              },
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: BlocBuilder<PlaceSearchCubit, PlaceSearchState>(
                  builder: (context, state) => state.query.isEmpty
                      ? Text(
                          'Search for a mall, a campus, a street or a '
                          'barangay.',
                          style: SearchTokens.text(
                            context,
                            color: SearchTokens.muted,
                          ),
                        )
                      : PlaceSearchResults(
                          state: state,
                          onPick: (p) => Navigator.of(context).pop(p),
                          onRetry: context.read<PlaceSearchCubit>().retry,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
