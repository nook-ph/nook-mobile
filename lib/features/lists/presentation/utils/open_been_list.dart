import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/lists/presentation/pages/list_detail_page.dart';

/// Opens the caller's Been list — the ranked one (docs/RANKING_DESIGN.md §3.2).
///
/// The score reveal's payoff CTA needs the list's id, which only [ListsBloc]
/// knows. Usually it is already loaded, but right after a first-ever Been the
/// lists refresh can still be in flight, so this waits for it rather than
/// silently doing nothing on the one screen the spec wants to route away from.
Future<void> openBeenList(BuildContext context) async {
  final bloc = context.read<ListsBloc>();
  final navigator = Navigator.of(context);
  var been = _beenListIn(bloc.state);

  if (been == null) {
    bloc.add(LoadUserLists());
    try {
      been = await bloc.stream
          .map(_beenListIn)
          .where((list) => list != null)
          .first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Timed out, errored, or the bloc closed — nothing to open.
      been = null;
    }
  }

  final list = been;
  if (list == null || !context.mounted) return;

  await navigator.push(
    MaterialPageRoute(
      builder: (_) => ListDetailPage(
        listId: list.id,
        title: list.name,
        listType: list.listType,
      ),
    ),
  );
}

CafeList? _beenListIn(ListsState state) {
  if (state is! ListsLoaded) return null;
  for (final list in state.lists) {
    if (list.listType == 'been') return list;
  }
  return null;
}
