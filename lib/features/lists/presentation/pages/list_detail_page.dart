import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/list_detail_cafe_card.dart';
import 'package:nook/features/lists/presentation/widgets/list_edit_dialogs.dart';
import 'package:nook/features/lists/presentation/widgets/list_options_bottom_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/ranked_been_list.dart';

class ListDetailPage extends StatefulWidget {
  final String listId;
  final String title;

  /// `lists.list_type` — 'been' switches the body to the ranked view
  /// (docs/RANKING_DESIGN.md §3.2). Callers that don't know default to the
  /// plain grid.
  final String listType;

  const ListDetailPage({
    super.key,
    required this.listId,
    required this.title,
    this.listType = 'custom',
  });

  bool get isBeenList => listType == 'been';

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  // Cache to survive bloc state changes during navigation
  List<CafeSummary>? _cachedCafes;
  String? _cachedDescription;
  String? _lastRemovedCafeName;
  CafeList? _cachedList;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<ListsBloc>().state;
    if (state is ListCafesLoaded && state.list.id == widget.listId) {
      _cachedCafes = state.cafes;
      _cachedDescription = state.list.description;
      _cachedList = state.list;
    } else {
      context.read<ListsBloc>().add(LoadListCafes(listId: widget.listId));
    }
    if (widget.isBeenList) {
      // The ranked view needs positions/scores; idempotent and cheap.
      final ranking = context.read<CafeRankingCubit>();
      if (!ranking.state.loaded) ranking.load();
    }
  }

  bool get _canEditList {
    final list = _cachedList;
    return list != null && !list.isSystem && !list.isDefault;
  }

  void _showListOptions() {
    final list = _cachedList;
    if (list == null) return;

    final bloc = context.read<ListsBloc>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ListOptionsBottomSheet(
        listId: list.id,
        listName: list.name,
        onEdit: () => _showEditDialog(bloc, list),
        onDelete: () => _confirmDelete(bloc, list),
      ),
    );
  }

  void _showEditDialog(ListsBloc bloc, CafeList list) {
    showDialog(
      context: context,
      builder: (_) => EditListDialog(
        currentName: list.name,
        currentDescription: list.description,
        currentIsPublic: list.isPublic,
        onSave: (name, description, isPublic) {
          bloc.add(
            UpdateList(
              listId: list.id,
              name: name,
              description: description,
              isPublic: isPublic,
            ),
          );
          showPrimaryToast(context, 'List updated.');
        },
      ),
    );
  }

  Future<void> _confirmDelete(ListsBloc bloc, CafeList list) async {
    final confirmed = await showDeleteListConfirm(
      context,
      listName: list.name,
    );
    if (!confirmed || !mounted || _isDeleting) return;

    // The list this page is showing is gone — leave before the bloc reloads
    // and this page rebuilds against a list that no longer exists.
    _isDeleting = true;
    bloc.add(DeleteList(listId: list.id));
    Navigator.of(context).pop();
  }

  void _removeCafe(CafeSummary cafe) {
    _lastRemovedCafeName = cafe.name;
    context.read<ListsBloc>().add(
      RemoveCafeFromList(listId: widget.listId, cafeId: cafe.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        leading: AdaptiveTap(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: Colors.black),
          ),
        ),
        // Rename / delete moved here when the Lists index dropped its ⋮.
        // Absent for system lists (the server refuses both) and for the
        // default list, whose bookmark saves would be orphaned by a delete.
        actions: [
          if (_canEditList)
            AdaptiveTap(
              onTap: _showListOptions,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.more_vert, color: Color(0xFF767574)),
              ),
            ),
        ],
      ),
      body: BlocConsumer<ListsBloc, ListsState>(
        listenWhen: (previous, current) =>
            previous is ListCafesLoaded || current is ListCafesLoaded,
        listener: (context, state) {
          if (state is ListCafesLoaded && state.list.id == widget.listId) {
            final hadRemoval =
                _lastRemovedCafeName != null &&
                state.cafes.length < (_cachedCafes?.length ?? 0);
            setState(() {
              _cachedCafes = state.cafes;
              _cachedDescription = state.list.description;
              _cachedList = state.list;
            });
            if (hadRemoval) {
              showPrimaryToast(context, 'Removed "${_lastRemovedCafeName!}".');
              _lastRemovedCafeName = null;
            }
          }
        },
        builder: (context, state) {
          final listsBloc = context.read<ListsBloc>();

          // Serve cached data immediately — no spinner flash on return
          if (_cachedCafes != null) {
            return _buildList(_cachedCafes!, _cachedDescription);
          }

          // No cache yet — show appropriate state
          if (state is ListsError) {
            final info = AppErrorCopy.fromException(state.error);
            return FullPageErrorWidget(
              error: info,
              onRetry: info.type == ErrorType.sessionExpired
                  ? () => context.push('/login')
                  : () => listsBloc.add(LoadListCafes(listId: widget.listId)),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildList(List<CafeSummary> cafes, String? description) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 600 ? 3 : 2;
        final horizontalPadding = columns == 3 ? 32.0 : 16.0;

        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 8.0,
          ),
          children: [
            Text(widget.title, style: context.textTheme.titleLargeSemi),
            if (description != null && description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF848586),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (cafes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No cafes in this list yet.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF848586),
                  ),
                ),
              )
            else if (widget.isBeenList)
              RankedBeenList(cafes: cafes)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: cafes.length,
                itemBuilder: (_, index) {
                  final cafe = cafes[index];
                  return ListDetailCafeCard(
                    cafe: cafe,
                    onRemove: () => _removeCafe(cafe),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}
