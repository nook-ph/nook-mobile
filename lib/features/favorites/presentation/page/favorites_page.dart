import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/favorites/bloc/favorites_bloc.dart';
import 'package:nook/features/favorites/bloc/favorites_state.dart';
import 'package:nook/features/favorites/presentation/widgets/favorite_card.dart';
import 'package:nook/features/profile/presentation/widgets/favorite_card.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Your Favorites',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 22.0,
      ),
      body: SafeArea(
        child: BlocBuilder<FavoritesBloc, FavoritesState>(
          builder: (context, state) {
            if (state is FavoritesLoading || state is FavoritesInitial) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.grey),
              );
            }

            if (state is FavoritesError) {
              return Center(
                child: Text(
                  state.message,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final favorites = state is FavoritesLoaded
                ? state.favorites
                : const [];

            if (favorites.isEmpty) {
              return const Center(
                child: Text(
                  'No favorites yet',
                  style: TextStyle(color: Colors.black54),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24.0),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                return ListCard(cafe: favorites[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
