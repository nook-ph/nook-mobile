import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/features/lists/presentation/pages/list_detail_page.dart';

/// Where the progress pill goes: the Want to try list, the cafes left.
///
/// An account opens its Want to try list (from [lists]); a guest, whose
/// Want to try lives on the Saved tab, goes to that tab. The list has no
/// sort of its own, so it opens in its usual order.
void openWantToTry(
  BuildContext context, {
  required String surface,
  List<CafeList> lists = const [],
}) {
  logAppEvent(
    SavesEvents.placesProgressTapped,
    properties: {'surface': surface},
  );
  final list = lists
      .where((l) => l.listType == CafeStatus.wantToTry.wire)
      .firstOrNull;
  if (list != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: ScreenNames.listDetail),
        builder: (_) => ListDetailPage(
          listId: list.id,
          title: list.name,
          listType: list.listType,
        ),
      ),
    );
    return;
  }
  try {
    context.read<NavigationBloc>().add(TabChange(tabIndex: MainShell.savedTab));
  } catch (_) {
    // No tab shell above (a test, a pushed page): nothing to switch.
  }
}
