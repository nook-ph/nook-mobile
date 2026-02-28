


import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_event.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';

class CafeDetailsBloc extends Bloc<CafeDetailsEvent, CafeDetailsStates> {
  final GetCafeDetailsUseCase getCafeDetailsUseCase;

  CafeDetailsBloc({required this.getCafeDetailsUseCase})
      : super(CafeDetailsInitialState()) {
    on<LoadCafeDetailsEvent>(_onLoadCafeDetails);
  }


  Future<void> _onLoadCafeDetails(LoadHomeDataEvent event, Emitter<HomeState> emit)
}