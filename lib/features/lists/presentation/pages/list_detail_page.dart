import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
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
          if (state is ListsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ListsError) {
            return _buildMessage(state.message);
          }

          if (state is ListCafesLoaded && state.list.id == widget.listId) {
            return _buildList(state.cafes);
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildList(List<CafeSummary> cafes) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
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

  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Color(0xFF848586)),
        ),
      ),
    );
  }
}
