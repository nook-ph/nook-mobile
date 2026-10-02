import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/cafe_list_display_title.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/presentation/cubit/save_to_list_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/list_form_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// "Save to…" (Figma "Save to list"): every custom list with a checkbox. A
/// tap saves at once; Done only closes the sheet.
class SaveToListBottomSheet extends StatefulWidget {
  const SaveToListBottomSheet({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<SaveToListBottomSheet> createState() => _SaveToListBottomSheetState();
}

class _SaveToListBottomSheetState extends State<SaveToListBottomSheet> {
  int _lastRefreshNonce = 0;
  bool _pendingCreateToast = false;

  @override
  void initState() {
    super.initState();
    context.read<SaveToListCubit>().load(widget.cafeId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SaveToListCubit, SaveToListState>(
      listenWhen: (previous, current) {
        if (previous is SaveToListLoaded && current is SaveToListLoaded) {
          return previous.listActionError != current.listActionError ||
              previous.refreshNonce != current.refreshNonce ||
              previous.isCreating != current.isCreating;
        }
        return current is SaveToListError;
      },
      listener: (context, state) {
        if (state is SaveToListLoaded) {
          if (state.refreshNonce != _lastRefreshNonce) {
            _lastRefreshNonce = state.refreshNonce;
            context.read<ListsBloc>().add(LoadUserLists());
          }

          final actionErr = state.listActionError;
          if (actionErr != null) {
            _pendingCreateToast = false;
            final info = AppErrorCopy.fromException(actionErr);
            showPrimaryToast(context, '${info.title} · ${info.subtitle}');
            context.read<SaveToListCubit>().acknowledgeListActionError();
          } else if (_pendingCreateToast && !state.isCreating) {
            _pendingCreateToast = false;
            showPrimaryToast(context, 'List created.');
          }
        } else if (state is SaveToListError) {
          _pendingCreateToast = false;
        }
      },
      builder: (context, state) {
        final loaded = state is SaveToListLoaded ? state : null;
        final hasLists = loaded != null && loaded.lists.isNotEmpty;
        // With no lists the sheet's own button is the way to make one.
        final showNewListPill = loaded == null || hasLists;

        return ListsSheet(
          title: 'Save to…',
          gap: 6,
          trailing: showNewListPill
              ? ListsPillButton(
                  label: 'New list',
                  icon: LucideIcons.plus,
                  style: ListsPillStyle.outlined,
                  height: 34,
                  fontSize: 12,
                  horizontalPadding: 12,
                  expand: false,
                  busy: loaded?.isCreating ?? false,
                  onTap: loaded == null ? null : _createList,
                )
              : null,
          footer: hasLists
              ? Padding(
                  // The design's 6 spacer between two 6 gaps.
                  padding: const EdgeInsets.only(top: 12),
                  child: ListsPillButton(
                    label: 'Done',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                )
              : null,
          children: _body(context, state),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, SaveToListState state) {
    if (state is SaveToListError) {
      final info = AppErrorCopy.fromException(state.error);
      final signIn = info.type == ErrorType.sessionExpired;
      return [
        _SheetError(
          info: info,
          onRetry: signIn
              ? () {
                  Navigator.of(context).pop();
                  context.push('/login');
                }
              : () => context.read<SaveToListCubit>().load(widget.cafeId),
        ),
      ];
    }

    if (state is! SaveToListLoaded) {
      return [for (var i = 0; i < 4; i++) const _SkeletonRow()];
    }

    if (state.lists.isEmpty) {
      return [
        Text(
          'Create a list to choose where this cafe should be saved.',
          style: listsText(14, color: ListsTokens.muted),
        ),
        Padding(
          // The design's 8 spacer between two 6 gaps.
          padding: const EdgeInsets.only(top: 8),
          child: ListsPillButton(
            label: 'New list',
            icon: LucideIcons.plus,
            busy: state.isCreating,
            onTap: _createList,
          ),
        ),
      ];
    }

    return [
      for (var i = 0; i < state.lists.length; i++) ...[
        if (i > 0) const ListsDivider(),
        _SaveToListRow(
          list: state.lists[i],
          isSaved: state.savedListIds.contains(state.lists[i].id),
          isEnabled:
              !state.isCreating &&
              !state.pendingListIds.contains(state.lists[i].id),
          onToggle: () => context.read<SaveToListCubit>().toggleList(
            cafeId: widget.cafeId,
            listId: state.lists[i].id,
          ),
        ),
      ],
    ];
  }

  Future<void> _createList() async {
    final input = await showCreateListSheet(context);
    if (!mounted || input == null) return;

    _pendingCreateToast = true;
    await context.read<SaveToListCubit>().createListAndSave(
      cafeId: widget.cafeId,
      name: input.name,
      description: input.description,
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
    final title = cafeListDisplayTitle(list);

    return Semantics(
      checked: isSaved,
      enabled: isEnabled,
      label: title,
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: isEnabled ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ListsThumb(
                imageUrl: list.coverImageUrl,
                size: 48,
                placeholderIcon: LucideIcons.bookmark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: listsText(14, weight: FontWeight.w500),
                    ),
                    Text(
                      list.isPublic ? 'Public' : 'Private',
                      style: listsText(12, color: ListsTokens.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Checkbox(checked: isSaved),
            ],
          ),
        ),
      ),
    );
  }
}

/// 24 square, radius 7: brand fill with a white tick, or a grey stroke.
class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? ListsTokens.brand : null,
        borderRadius: BorderRadius.circular(7),
        border: checked
            ? null
            : Border.all(color: ListsTokens.checkbox, width: 1.5),
      ),
      child: checked
          ? const Icon(LucideIcons.check, size: 14, color: ListsTokens.surface)
          : null,
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ListsSkeleton(width: 48, height: 48, radius: 12),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListsSkeleton(width: 130, height: 14),
              SizedBox(height: 8),
              ListsSkeleton(width: 70, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// The sheet's own error block: the app's error copy, centred, with one
/// outlined pill.
class _SheetError extends StatelessWidget {
  const _SheetError({required this.info, required this.onRetry});

  final ErrorInfo info;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final signIn = info.type == ErrorType.sessionExpired;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: ListsTokens.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FullPageErrorWidget.iconFor(info.type),
              size: 22,
              color: ListsTokens.brand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            info.title,
            textAlign: TextAlign.center,
            style: listsText(16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            info.subtitle,
            textAlign: TextAlign.center,
            style: listsText(14, color: ListsTokens.muted),
          ),
          // The design's 6 spacer between two 6 gaps.
          const SizedBox(height: 18),
          ListsPillButton(
            label: signIn ? 'Sign in' : 'Try again',
            style: signIn ? ListsPillStyle.filled : ListsPillStyle.outlined,
            height: 40,
            expand: false,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}
