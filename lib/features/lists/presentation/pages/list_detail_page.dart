import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/features/home_page/presentation/widgets/recommended_card.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';

class ListDetailPage extends StatefulWidget {
  final String listId;
  final String title;

  const ListDetailPage({super.key, required this.listId, required this.title});

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  bool _isEditMode = false;
  final Set<String> _selectedIds = {};

  // Cache to survive bloc state changes during navigation
  List<CafeSummary>? _cachedCafes;
  String? _cachedDescription;

  @override
  void initState() {
    super.initState();
    final state = context.read<ListsBloc>().state;
    if (state is ListCafesLoaded && state.list.id == widget.listId) {
      _cachedCafes = state.cafes;
      _cachedDescription = state.list.description;
    } else {
      context.read<ListsBloc>().add(LoadListCafes(listId: widget.listId));
    }
  }

  void _enterEditMode() => setState(() => _isEditMode = true);

  void _exitEditMode() => setState(() {
    _isEditMode = false;
    _selectedIds.clear();
  });

  void _toggleSelection(String cafeId) {
    setState(() {
      if (_selectedIds.contains(cafeId)) {
        _selectedIds.remove(cafeId);
      } else {
        _selectedIds.add(cafeId);
      }
    });
  }

  void _deleteSelected() {
    for (final id in _selectedIds) {
      context.read<ListsBloc>().add(
        RemoveCafeFromList(listId: widget.listId, cafeId: id),
      );
    }
    _exitEditMode();
  }

  void _deleteSingle(String cafeId) {
    context.read<ListsBloc>().add(
      RemoveCafeFromList(listId: widget.listId, cafeId: cafeId),
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
        leading: IconButton(
          icon: Icon(
            _isEditMode ? Icons.close : Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: _isEditMode
              ? _exitEditMode
              : () => Navigator.of(context).pop(),
        ),
        title: _isEditMode
            ? Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              )
            : null,
        actions: _isEditMode
            ? [
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: _selectedIds.isEmpty ? Colors.grey : Colors.red,
                  ),
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              ]
            : null,
      ),
      body: BlocConsumer<ListsBloc, ListsState>(
        listener: (context, state) {
          // Keep cache up to date whenever fresh data arrives
          if (state is ListCafesLoaded && state.list.id == widget.listId) {
            setState(() {
              _cachedCafes = state.cafes;
              _cachedDescription = state.list.description;
            });
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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      children: [
        if (!_isEditMode) ...[
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (description != null && description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF848586),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
        if (cafes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              'No cafes in this list yet.',
              style: TextStyle(fontSize: 15, color: Color(0xFF848586)),
            ),
          )
        else
          for (final cafe in cafes) ...[
            _buildCafeItem(cafe),
            const SizedBox(height: 16),
          ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildCafeItem(CafeSummary cafe) {
    final isSelected = _selectedIds.contains(cafe.id);

    return GestureDetector(
      onLongPress: _isEditMode ? null : _enterEditMode,
      onTap: _isEditMode ? () => _toggleSelection(cafe.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? const Color(0xFFF0F0F0) : Colors.transparent,
        ),
        child: Row(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _isEditMode
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(cafe.id),
                        activeColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _isEditMode
                  ? RecommendedCard(cafe: cafe)
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Slidable(
                          key: Key(cafe.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.22,
                            children: [
                              CustomSlidableAction(
                                onPressed: (_) => _deleteSingle(cafe.id),
                                backgroundColor: Colors.transparent,
                                borderRadius: BorderRadius.zero,
                                child: const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          child: RecommendedCard(cafe: cafe),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
