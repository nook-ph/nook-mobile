import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/cafe_list_display_title.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/presentation/widgets/bookmark_icon_button.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/section_error_widget.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/presentation/cubit/save_to_list_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/create_list_dialog.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SaveToListBottomSheet extends StatefulWidget {
  const SaveToListBottomSheet({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<SaveToListBottomSheet> createState() => _SaveToListBottomSheetState();
}

class _SaveToListBottomSheetState extends State<SaveToListBottomSheet> {
  late final DraggableScrollableController _sheetController;
  int _lastRefreshNonce = 0;
  bool _pendingCreateToast = false;
  int _lastAnimatedListCount = -1;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    context.read<SaveToListCubit>().load(widget.cafeId);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SaveToListCubit, SaveToListState>(
      listenWhen: (previous, current) {
        if (previous is SaveToListLoaded && current is SaveToListLoaded) {
          return previous.listActionError != current.listActionError ||
              previous.refreshNonce != current.refreshNonce;
        }
        return current is SaveToListError;
      },
      listener: (context, state) {
        if (state is SaveToListLoaded) {
          if (state.lists.length != _lastAnimatedListCount) {
            _lastAnimatedListCount = state.lists.length;
            if (_sheetController.isAttached) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_sheetController.isAttached) return;
                final target = _targetChildSize(context, state.lists.length);
                _sheetController.animateTo(
                  target,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
              });
            }
          }

          if (state.refreshNonce != _lastRefreshNonce) {
            _lastRefreshNonce = state.refreshNonce;
            context.read<ListsBloc>().add(LoadUserLists());
          }

          if (_pendingCreateToast && !state.isCreating) {
            _pendingCreateToast = false;
            showPrimaryToast(context, 'List created.');
          }

          final actionErr = state.listActionError;
          if (actionErr != null) {
            _pendingCreateToast = false;
            final info = AppErrorCopy.fromException(actionErr);
            showPrimaryToast(context, '${info.title} · ${info.subtitle}');
            context.read<SaveToListCubit>().acknowledgeListActionError();
          }
        } else if (state is SaveToListError) {
          _pendingCreateToast = false;
        }
      },
      builder: (context, state) {
        return DraggableScrollableSheet(
          controller: _sheetController,
          expand: false,
          snap: true,
          minChildSize: 0.28,
          initialChildSize: 0.45,
          maxChildSize: 0.75,
          builder: (context, scrollController) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Save to...', style: context.textTheme.titleLargeSemi),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _SaveToListContent(
                        state: state,
                        scrollController: scrollController,
                        cafeId: widget.cafeId,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _NewListButton(
                      isEnabled: state is SaveToListLoaded && !state.isCreating,
                      isLoading: state is SaveToListLoaded && state.isCreating,
                      onPressed: _showCreateListDialog,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _targetChildSize(BuildContext context, int rowCount) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final contentHeight = 192 + (rowCount * 80) + 96;
    final targetSize = contentHeight / screenHeight;
    return targetSize.clamp(0.32, 0.75).toDouble();
  }

  Future<void> _showCreateListDialog() async {
    final input = await showGeneralDialog<CreateListInput>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Center(child: CreateListDialog());
      },
    );

    if (!mounted || input == null) return;
    _pendingCreateToast = true;
    await context.read<SaveToListCubit>().createListAndSave(
      cafeId: widget.cafeId,
      name: input.name,
      description: input.description,
    );
  }
}

class _SaveToListContent extends StatelessWidget {
  const _SaveToListContent({
    required this.state,
    required this.scrollController,
    required this.cafeId,
  });

  final SaveToListState state;
  final ScrollController scrollController;
  final String cafeId;

  @override
  Widget build(BuildContext context) {
    if (state is SaveToListInitial || state is SaveToListLoading) {
      return Skeletonizer(
        enabled: true,
        effect: const PulseEffect(),
        child: ListView.separated(
          controller: scrollController,
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, _) => const _SaveToListSkeletonRow(),
        ),
      );
    }

    if (state is SaveToListError) {
      final err = state as SaveToListError;
      final info = AppErrorCopy.fromException(err.error);
      return ListView(
        controller: scrollController,
        children: [
          SectionErrorWidget(
            error: info,
            onRetry: info.type == ErrorType.sessionExpired
                ? () {
                    Navigator.of(context).pop();
                    context.push('/login');
                  }
                : () => context.read<SaveToListCubit>().load(cafeId),
          ),
        ],
      );
    }

    final loaded = state as SaveToListLoaded;
    if (loaded.lists.isEmpty) {
      return ListView(
        controller: scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Create a list to choose where this cafe should be saved.',
              style: context.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: loaded.lists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final list = loaded.lists[index];
        final isPending = loaded.pendingListIds.contains(list.id);
        final isSaved = loaded.savedListIds.contains(list.id);

        return _SaveToListRow(
          list: list,
          isSaved: isSaved,
          isEnabled: !loaded.isCreating && !isPending,
          onToggle: () => context.read<SaveToListCubit>().toggleList(
            cafeId: cafeId,
            listId: list.id,
          ),
        );
      },
    );
  }
}

class _SaveToListRow extends StatelessWidget {
  const _SaveToListRow({
    required this.list,
    required this.isSaved,
    required this.isEnabled,
    required this.onToggle,
  });

  final CafeList list;
  final bool isSaved;
  final bool isEnabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onToggle : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _ListCoverThumbnail(imageUrl: list.coverImageUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafeListDisplayTitle(list),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMediumSemi.copyWith(
                        color: context.colorScheme.black,
                      ),
                    ),

                    Text(
                      list.isPublic ? 'Public' : 'Private',
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IgnorePointer(
                child: BookmarkIconButton(
                  isSaved: isSaved,
                  isEnabled: true,
                  onTap: null,
                  showCircleBackground: false,
                  iconSize: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListCoverThumbnail extends StatelessWidget {
  const _ListCoverThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const _ListCoverPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: trimmed,
      fit: BoxFit.cover,
      placeholder: (_, _) => const _ListCoverPlaceholder(),
      errorWidget: (_, _, _) => const _ListCoverPlaceholder(),
    );
  }
}

class _ListCoverPlaceholder extends StatelessWidget {
  const _ListCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.image_outlined, color: Color(0xFF6B7280)),
    );
  }
}

class _SaveToListSkeletonRow extends StatelessWidget {
  const _SaveToListSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Bone.square(
            size: 64,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(fontSize: 18, words: 2),
                SizedBox(height: 8),
                Bone.text(fontSize: 15, width: 88),
              ],
            ),
          ),
          SizedBox(width: 4),
          Bone.iconButton(size: 32),
        ],
      ),
    );
  }
}

class _NewListButton extends StatelessWidget {
  const _NewListButton({
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AdaptiveFilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF344E41),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: 24),
            const SizedBox(width: 8),
            Text(
              'New list',
              style: context.textTheme.titleMediumSemi.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
