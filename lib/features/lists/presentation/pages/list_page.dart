import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
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
import 'package:nook/features/lists/presentation/widgets/create_list_dialog.dart';
import 'package:nook/features/lists/presentation/widgets/list_options_bottom_sheet.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  String? _pendingEditName;
  String? _pendingDeleteName;
  String? _pendingCreateName;
  bool _isCreating = false;

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
          _pendingEditName = null;
          _pendingDeleteName = null;
          _pendingCreateName = null;
          if (mounted) setState(() => _isCreating = false);
          return;
        }

        if (state is ListsLoaded) {
          if (_pendingEditName != null) {
            showPrimaryToast(context, 'List updated.');
            _pendingEditName = null;
          }

          if (_pendingDeleteName != null) {
            showPrimaryToast(context, 'List deleted.');
            _pendingDeleteName = null;
          }

          if (_pendingCreateName != null) {
            showPrimaryToast(context, 'List created.');
            _pendingCreateName = null;
            if (mounted) setState(() => _isCreating = false);
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
              ? AdaptiveTap(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back, color: Colors.black),
                  ),
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
                Text(
                  'Your Lists',
                  style: context.textTheme.titleLargeSemi,
                ),
                const SizedBox(height: 20),
                _buildFavoritesCard(context, defaultList),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'All Lists',
                      style: context.textTheme.titleMediumSemi.copyWith(
                        color: const Color(0xFF1E3A2B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (regularLists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'Create a list to start organizing your saved cafes.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF848586)),
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
          heroTag: 'fab-list-create',
          onPressed: _isCreating ? null : () => _showCreateListDialog(context),
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

  Future<void> _showCreateListDialog(BuildContext context) async {
    final listsBloc = context.read<ListsBloc>();

    final input = await showDialog<CreateListInput>(
      context: context,
      builder: (_) => const CreateListDialog(),
    );

    if (input == null || !mounted) return;

    setState(() => _isCreating = true);
    _pendingCreateName = input.name;
    listsBloc.add(
      CreateList(
        name: input.name,
        description: input.description,
        isPublic: false,
      ),
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
                  Text(
                    'Favorites',
                    style: context.textTheme.bodyLargeMed.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _placeCountText(favoritesList?.cafeCount ?? 0),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF848586),
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
        onEdit: () => _showEditDialog(context, bloc, list),
        onDelete: () => _showDeleteDialog(context, bloc, list.id, list.name),
      ),
    );
  }

  void _showEditDialog(BuildContext context, ListsBloc bloc, CafeList list) {
    showDialog(
      context: context,
      builder: (_) => _EditListDialog(
        currentName: list.name,
        currentDescription:
            list.description, // Assuming CafeList has a description field
        currentIsPublic: list.isPublic,
        onSave: (newName, newDesc, newIsPublic) {
          _pendingEditName = list.name;
          bloc.add(
            UpdateList(
              listId: list.id,
              name: newName,
              description: newDesc,
              isPublic: newIsPublic,
            ),
          );
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
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete list?',
                style: context.textTheme.titleMediumSemi,
              ),
              const SizedBox(height: 16),
              Text(
                '"$listName" will be permanently deleted. Cafes won\'t be deleted.',
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
                Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdaptiveTextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: context.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AdaptiveTextButton(
                    onPressed: () {
                      _pendingDeleteName = listName;
                      bloc.add(DeleteList(listId: listId));
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Delete',
                      style: context.textTheme.bodyMedium?.copyWith(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  static String _imageUrl(String? imageUrl) => imageUrl?.trim() ?? '';
}

class _EditListDialog extends StatefulWidget {
  final String currentName;
  final String? currentDescription;
  final bool currentIsPublic;
  final void Function(String name, String? description, bool isPublic) onSave;

  const _EditListDialog({
    required this.currentName,
    this.currentDescription,
    required this.currentIsPublic,
    required this.onSave,
  });

  @override
  State<_EditListDialog> createState() => _EditListDialogState();
}

class _EditListDialogState extends State<_EditListDialog> {
  static const _green = Color(0xFF344E41);

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late bool _isPublic;

  String get _trimmedName => _nameController.text.trim();
  String get _trimmedDesc => _descController.text.trim();

  bool get _canSave {
    if (_trimmedName.isEmpty) return false;
    // Check if any value has changed
    return _trimmedName != widget.currentName ||
        _trimmedDesc != (widget.currentDescription ?? '') ||
        _isPublic != widget.currentIsPublic;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName)
      ..addListener(_onFormChanged);
    _descController = TextEditingController(
      text: widget.currentDescription ?? '',
    )..addListener(_onFormChanged);
    _isPublic = widget.currentIsPublic;
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _descController.removeListener(_onFormChanged);
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {}); // Triggers rebuild to evaluate _canSave
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit list',
              style: context.textTheme.titleMediumSemi,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    maxLength: 50,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'List name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _green, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveIfValid(context),
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _green, width: 2),
                      ),
                    ),
                  ),
                  // const SizedBox(height: 16),
                  // SwitchListTile(
                  //   contentPadding: EdgeInsets.zero,
                  //   title: Text(
                  //     'Public list',
                  //     style: context.textTheme.bodyLargeMed,
                  //   ),
                  //   subtitle: Text(
                  //     'Anyone can view this list',
                  //     style: context.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  //   ),
                  //   value: _isPublic,
                  //   activeColor: _green,
                  //   onChanged: (bool value) {
                  //     setState(() {
                  //       _isPublic = value;
                  //     });
                  //   },
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdaptiveTextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: context.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                AdaptiveElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF33523F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _canSave ? () => _saveIfValid(context) : null,
                  child: Text(
                    'Save',
                    style: context.textTheme.bodySmallMed.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveIfValid(BuildContext context) {
    if (!_canSave) return;

    widget.onSave(
      _trimmedName,
      _trimmedDesc.isEmpty ? null : _trimmedDesc,
      _isPublic,
    );
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
              child: _buildCoverImage(imageUrl),
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
                            style: context.textTheme.titleMedium?.copyWith(
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
                      style: context.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
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

  Widget _buildCoverImage(String imageUrl) {
    final isEmpty = imageUrl.trim().isEmpty;

    if (isEmpty) return _placeholder();

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8E8E8), Color(0xFF9E9E9E)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.coffee, color: Color(0xFFBDBDBD), size: 36),
      ),
    );
  }
}
