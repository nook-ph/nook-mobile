import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/lists/presentation/pages/list_detail_page.dart';
import 'package:nook/features/lists/presentation/widgets/list_options_bottom_sheet.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  static const _fallbackImageUrl =
      'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';
  String? _pendingRenameName;
  String? _pendingDeleteName;

  @override
  void initState() {
    super.initState();
    context.read<ListsBloc>().add(LoadUserLists());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListsBloc, ListsState>(
      listener: (context, state) {
        if (state is ListsError) {
          final info = AppErrorCopy.fromException(state.error);
          showPrimaryToast(context, '${info.title} · ${info.subtitle}');
          _pendingRenameName = null;
          _pendingDeleteName = null;
          return;
        }

        if (state is ListsLoaded) {
          if (_pendingRenameName != null) {
            showPrimaryToast(context, 'List renamed.');
            _pendingRenameName = null;
          }

          if (_pendingDeleteName != null) {
            showPrimaryToast(context, 'List deleted.');
            _pendingDeleteName = null;
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFFFF),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.white,
          automaticallyImplyLeading: widget.showBackButton,
          leading: widget.showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
        body: BlocBuilder<ListsBloc, ListsState>(
          builder: (context, state) {
            final listsBloc = context.read<ListsBloc>();
            final lists = state is ListsLoaded
                ? state.lists
                : listsBloc.userLists;
            final defaultList = _defaultList(lists);
            final regularLists = lists
                .where((list) => !list.isDefault)
                .toList(growable: false);

            if (state is ListsLoading && lists.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ListsError && lists.isEmpty) {
              final info = AppErrorCopy.fromException(state.error);
              return FullPageErrorWidget(
                error: info,
                onRetry: info.type == ErrorType.sessionExpired
                    ? () => context.push('/login')
                    : () => listsBloc.add(LoadUserLists()),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              children: [
                const Text(
                  'Your Lists',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFavoritesCard(context, defaultList),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'All Lists',
                      style: TextStyle(
                        color: Color(0xFF1E3A2B),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AdaptiveTap(
                      onTap: () {},
                      child: const Text(
                        'Sort by: Recent',
                        style: TextStyle(
                          color: Color(0xFF33523F),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (regularLists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'Create a list to start organizing your saved cafes.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF848586)),
                    ),
                  )
                else
                  for (final list in regularLists) ...[
                    CollectionCard(
                      title: list.name,
                      subtitle:
                          '${_placeCountText(list.cafeCount)} • ${_visibilityText(list)}',
                      imageUrl: _imageUrl(list.coverImageUrl),
                      onTap: () => _openList(context, list),
                      onOptionsTap: () => _showListOptions(context, list),
                    ),
                    const SizedBox(height: 16),
                  ],
                const SizedBox(height: 80),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateListModal(context),
          backgroundColor: const Color(0xFF33523F),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _showCreateListModal(BuildContext context) {
    final listsBloc = context.read<ListsBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: listsBloc,
          child: _CreateListSheet(
            listsBloc: listsBloc,
          ),
        );
      },
    );
  }

  Widget _buildFavoritesCard(BuildContext context, CafeList? favoritesList) {
    final listId =
        favoritesList?.id ?? context.read<ListsBloc>().defaultListId?.trim();

    return InkWell(
      onTap: () {
        if (listId == null || listId.isEmpty) {
          context.read<ListsBloc>().add(LoadUserLists());
          showPrimaryToast(context, 'Favorites are still loading.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListDetailPage(
              listId: listId,
              title: favoritesList?.name ?? 'Favorites',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF33523F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Favorites',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),

                  Text(
                    _placeCountText(favoritesList?.cafeCount ?? 0),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF848586),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF848586), size: 28),
          ],
        ),
      ),
    );
  }

  void _openList(BuildContext context, CafeList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListDetailPage(listId: list.id, title: list.name),
      ),
    );
  }

  void _showListOptions(BuildContext context, CafeList list) {
    final bloc = context.read<ListsBloc>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ListOptionsBottomSheet(
        listId: list.id,
        listName: list.name,
        onRename: () => _showRenameDialog(context, bloc, list.id, list.name),
        onDelete: () => _showDeleteDialog(context, bloc, list.id, list.name),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    ListsBloc bloc,
    String listId,
    String currentName,
  ) {
    showDialog(
      context: context,
      builder: (_) => _RenameListDialog(
        currentName: currentName,
        onSave: (newName) {
          _pendingRenameName = currentName;
          bloc.add(RenameList(listId: listId, name: newName));
        },
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    ListsBloc bloc,
    String listId,
    String listName,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete list?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '"$listName" will be permanently deleted. Cafes won\'t be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _pendingDeleteName = listName;
              bloc.add(DeleteList(listId: listId));
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  CafeList? _defaultList(List<CafeList> lists) {
    for (final list in lists) {
      if (list.isDefault) return list;
    }
    return null;
  }

  static String _placeCountText(int count) {
    return '$count ${count == 1 ? 'Place' : 'Places'}';
  }

  static String _visibilityText(CafeList list) {
    return list.isPublic ? 'Public' : 'Private';
  }

  static String _imageUrl(String? imageUrl) {
    final trimmed = imageUrl?.trim();
    return trimmed == null || trimmed.isEmpty ? _fallbackImageUrl : trimmed;
  }
}

class _CreateListSheet extends StatefulWidget {
  final ListsBloc listsBloc;

  const _CreateListSheet({
    required this.listsBloc,
  });

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListsBloc, ListsState>(
      listener: (context, state) {
        if (!_isLoading) return;

        if (state is ListsLoaded) {
          debugPrint(
            '[ListsPage] CreateList completed; '
            'loadedLists=${state.lists.length}',
          );
          Navigator.pop(context);
          showPrimaryToast(context, 'List created.');
          return;
        }

        if (state is ListsError) {
          debugPrint(
            '[ListsPage] CreateList emitted ListsError error=${state.error}',
          );
          if (mounted) {
            setState(() => _isLoading = false);
          }
          final info = AppErrorCopy.fromException(state.error);
          showPrimaryToast(context, '${info.title} · ${info.subtitle}');
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24.0,
          right: 24.0,
          top: 24.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create New List',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: true,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'List Name',
                hintText: 'e.g., Cebu Specialty Spots',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(
                    color: Color(0xFF33523F),
                    width: 2.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              enabled: !_isLoading,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'What is this list for?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(
                    color: Color(0xFF33523F),
                    width: 2.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF33523F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create List',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showPrimaryToast(context, 'List name is required.');
      return;
    }

    final desc = _descController.text.trim();
    debugPrint(
      '[ListsPage] Dispatch CreateList '
      'nameLength=${name.length} '
      'hasDescription=${desc.isNotEmpty}',
    );
    setState(() => _isLoading = true);
    widget.listsBloc.add(
      CreateList(name: name, description: desc.isNotEmpty ? desc : null),
    );
  }
}

class _RenameListDialog extends StatefulWidget {
  final String currentName;
  final ValueChanged<String> onSave;

  const _RenameListDialog({required this.currentName, required this.onSave});

  @override
  State<_RenameListDialog> createState() => _RenameListDialogState();
}

class _RenameListDialogState extends State<_RenameListDialog> {
  static const _green = Color(0xFF344E41);

  late final TextEditingController _controller;

  String get _trimmedName => _controller.text.trim();

  bool get _canSave =>
      _trimmedName.isNotEmpty && _trimmedName != widget.currentName.trim();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName)
      ..addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Rename list',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 50,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _saveIfValid(context),
        decoration: InputDecoration(
          labelText: 'List name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _canSave ? () => _saveIfValid(context) : null,
          style: TextButton.styleFrom(foregroundColor: _green),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveIfValid(BuildContext context) {
    if (!_canSave) return;

    widget.onSave(_trimmedName);
    Navigator.pop(context);
  }
}

class CollectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final Widget? footerWidget;
  final bool isSkeleton;
  final VoidCallback? onTap;
  final VoidCallback? onOptionsTap;

  const CollectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.footerWidget,
    this.isSkeleton = false,
    this.onTap,
    this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: () {
        if (isSkeleton) return;
        onTap?.call();
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        AdaptiveTap(
                          onTap: isSkeleton ? null : onOptionsTap,
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                Icons.more_vert,
                                size: 20,
                                color: Color(0xFF848586),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    if (footerWidget != null) ...[
                      const SizedBox(height: 16),
                      footerWidget!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
