import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  @override
  void initState() {
    super.initState();
    context.read<ListsBloc>().add(LoadListCafes(listId: widget.listId));
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocBuilder<ListsBloc, ListsState>(
        builder: (context, state) {
          final listsBloc = context.read<ListsBloc>();

          if (state is ListsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ListsError) {
            final info = AppErrorCopy.fromException(state.error);
            return FullPageErrorWidget(
              error: info,
              onRetry: info.type == ErrorType.sessionExpired
                  ? () => context.push('/login')
                  : () => listsBloc.add(LoadListCafes(listId: widget.listId)),
            );
          }

          if (state is ListCafesLoaded && state.list.id == widget.listId) {
            return _buildList(state.cafes, state.list.description);
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
            RecommendedCard(cafe: cafe),
            const SizedBox(height: 16),
          ],
        const SizedBox(height: 80),
      ],
    );
  }
}
