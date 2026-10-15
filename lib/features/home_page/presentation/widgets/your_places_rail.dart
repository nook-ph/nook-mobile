import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/places_progress.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/core/widgets/prototype_height.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/account_want_to_try_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/recently_viewed_cubit.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_rail_impression.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/lists/presentation/widgets/places_progress_pill.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// The cafes for "Your places": Want to Try first (newest first), then the
/// recently viewed ones not already in it, at most [max].
List<CafeSummary> yourPlaces({
  required List<CafeSummary> wantToTry,
  required List<CafeSummary> recent,
  int max = YourPlacesRail.maxCards,
}) {
  final seen = <String>{};
  final out = <CafeSummary>[];
  for (final cafe in [...wantToTry, ...recent]) {
    if (out.length >= max) break;
    if (cafe.id.isEmpty || !seen.add(cafe.id)) continue;
    out.add(cafe);
  }
  return out;
}

/// "Your places" at the top of Home: the Want to Try list, then cafes opened
/// lately, so a second visit opens on something of the person's own rather
/// than the same shelves as the first. For guests (saves kept on this phone)
/// and accounts alike. Renders nothing while empty.
class YourPlacesRail extends StatefulWidget {
  const YourPlacesRail({super.key, this.isSignedIn, this.repository});

  /// Rail id for analytics: `section` on its cards, and `rail` on
  /// `home_rail_impression` / `home_rail_card_tapped`.
  static const railId = 'your_places';
  static const title = 'Your places';
  static const maxCards = 15;

  /// Defaults to the Supabase session; tests pass their own.
  final bool Function()? isSignedIn;

  /// Defaults to the app's; tests pass their own.
  final ICafeRepository? repository;

  @override
  State<YourPlacesRail> createState() => _YourPlacesRailState();
}

class _YourPlacesRailState extends State<YourPlacesRail> {
  AccountWantToTryCubit? _account;

  bool get _signedIn =>
      widget.isSignedIn?.call() ??
      Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    final repository =
        widget.repository ??
        (sl.isRegistered<ICafeRepository>() ? sl<ICafeRepository>() : null);
    if (repository != null) {
      _account = AccountWantToTryCubit(repository: repository);
    }
    unawaited(context.read<RecentlyViewedCubit>().load());
    unawaited(context.read<GuestSavesCubit>().load());
    _loadAccount();
  }

  void _loadAccount({List<CafeList>? lists}) {
    final account = _account;
    if (account == null) return;
    if (!_signedIn) {
      account.clear();
      return;
    }
    final known = lists ?? _listsInHand();
    unawaited(account.load(lists: known));
  }

  List<CafeList>? _listsInHand() {
    final bloc = _maybeListsBloc();
    if (bloc == null) return null;
    final lists = bloc.userLists;
    return lists.isEmpty ? null : lists;
  }

  ListsBloc? _maybeListsBloc() {
    try {
      return context.read<ListsBloc>();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _account?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget row(List<CafeSummary> accountCafes) =>
        BlocBuilder<GuestSavesCubit, GuestSavesState>(
          builder: (context, guest) =>
              BlocBuilder<RecentlyViewedCubit, List<RecentlyViewedCafe>>(
                builder: (context, recent) {
                  final wantToTry = _signedIn
                      ? accountCafes
                      : [
                          for (final s in guest.withStatus(
                            CafeStatus.wantToTry,
                          ))
                            s.cafe.toSummary(),
                        ];
                  return YourPlacesRow(
                    cafes: yourPlaces(
                      wantToTry: wantToTry,
                      recent: [for (final r in recent) r.cafe.toSummary()],
                    ),
                    progress: _signedIn
                        ? PlacesProgress.fromLists(
                            _maybeListsBloc()?.userLists ?? const [],
                          )
                        : PlacesProgress.fromStatuses(
                            guest.saves.map((s) => s.status),
                          ),
                  );
                },
              ),
        );

    final account = _account;
    final listsBloc = _maybeListsBloc();
    // A fresh row on every account change: handing BlocBuilder the same
    // widget instance would skip the rebuild.
    final content = account == null
        ? row(const [])
        : BlocBuilder<AccountWantToTryCubit, List<CafeSummary>>(
            bloc: account,
            builder: (_, cafes) => listsBloc == null
                ? row(cafes)
                // The progress counts come from the lists; follow them.
                : BlocBuilder<ListsBloc, ListsState>(
                    bloc: listsBloc,
                    builder: (_, _) => row(cafes),
                  ),
          );

    final listeners = <BlocListener>[
      BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            (current is AuthAuthenticated && previous is! AuthAuthenticated) ||
            current is AuthLoggedOut ||
            current is AuthUnauthenticated ||
            current is AuthAccountDeleted,
        listener: (_, _) {
          // Guest or account Want to Try: which one the row shows changed.
          setState(() {});
          _loadAccount();
        },
      ),
    ];
    if (listsBloc != null) {
      // A status set anywhere reloads the lists; the row follows.
      listeners.add(
        BlocListener<ListsBloc, ListsState>(
          listenWhen: (_, current) => current is ListsLoaded,
          listener: (_, state) {
            if (state is ListsLoaded) _loadAccount(lists: state.lists);
          },
        ),
      );
    }
    return MultiBlocListener(listeners: listeners, child: content);
  }
}

/// The row itself: a titled horizontal shelf of Home's compact cards, with
/// the gap Home puts between shelves under it. Nothing when [cafes] is empty.
/// Logs `home_rail_impression` and `home_rail_card_tapped` as `your_places`.
class YourPlacesRow extends StatelessWidget {
  const YourPlacesRow({super.key, required this.cafes, this.progress});

  final List<CafeSummary> cafes;

  /// "Been to 3 of 8" beside the title. Shown only while something is
  /// still on Want to Try: the rail leads with those, and with none left
  /// the count has no goal to point at.
  final PlacesProgress? progress;

  static const _prototypeCafe = CafeSummary(
    id: '',
    name: 'Prototype Cafe Name',
    address: 'Prototype Address',
    rating: 4.9,
    tags: ['Specialty'],
  );

  @override
  Widget build(BuildContext context) {
    if (cafes.isEmpty) return const SizedBox.shrink();
    final showProgress = (progress?.wantToTry ?? 0) > 0;
    final imageHeight = ResponsiveCardSizes.cafeImageHeight(context);
    final cardWidth = ResponsiveCardSizes.cafeCardWidth(context);
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionTitle(
            YourPlacesRail.title,
            trailing: showProgress
                ? PlacesProgressPill(progress: progress!)
                : null,
          ),
          const SizedBox(height: 12),
          PrototypeHeight(
            prototype: HomeCafeCard(
              cafe: _prototypeCafe,
              width: cardWidth,
              height: imageHeight,
              isSkeleton: true,
            ),
            listView: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: ResponsiveCardSizes.homeGutter,
              ),
              itemCount: cafes.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: ResponsiveCardSizes.homeCardGap),
              itemBuilder: (_, index) => HomeCafeCard(
                cafe: cafes[index],
                width: cardWidth,
                height: imageHeight,
                section: YourPlacesRail.railId,
                position: index,
                rail: YourPlacesRail.railId,
              ),
            ),
          ),
        ],
      ),
    );
    return HomeRailImpression(rail: YourPlacesRail.railId, child: row);
  }
}
