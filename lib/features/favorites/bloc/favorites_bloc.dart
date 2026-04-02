import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/usecases/add_favorite_cafe_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_favorite_cafes_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/remove_favorite_cafe_usecase.dart';
import 'package:nook/features/favorites/bloc/favorites_events.dart';
import 'package:nook/features/favorites/bloc/favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final GetFavoriteCafesUseCase getFavoriteCafesUseCase;
  final AddFavoriteCafeUseCase addFavoriteCafeUseCase;
  final RemoveFavoriteCafeUseCase removeFavoriteCafeUseCase;

  FavoritesBloc({
    required this.getFavoriteCafesUseCase,
    required this.addFavoriteCafeUseCase,
    required this.removeFavoriteCafeUseCase,
  }) : super(FavoritesInitial()) {
    on<LoadFavoritesEvent>(_onLoadFavorites);
    on<ToggleFavoriteEvent>(_onToggleFavorite);
  }

  Future<void> _onLoadFavorites(
    LoadFavoritesEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(FavoritesLoading());

    try {
      final favorites = await getFavoriteCafesUseCase.call(userId: event.userId);
      emit(FavoritesLoaded(favorites));
    } catch (e) {
      emit(FavoritesError(e.toString()));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavoriteEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FavoritesLoaded) {
      add(LoadFavoritesEvent(userId: event.userId));
      return;
    }

    try {
      final currentFavorites = List<CafeSummary>.from(currentState.favorites);
      final index = currentFavorites.indexWhere((c) => c.id == event.cafeId);

      if (index >= 0) {
        await removeFavoriteCafeUseCase.call(event.cafeId, userId: event.userId);
        currentFavorites.removeAt(index);
      } else {
        await addFavoriteCafeUseCase.call(event.cafeId, userId: event.userId);
        currentFavorites.insert(0, event.cafe);
      }

      emit(FavoritesLoaded(currentFavorites));
    } catch (e) {
      emit(FavoritesError(e.toString()));
    }
  }
}
