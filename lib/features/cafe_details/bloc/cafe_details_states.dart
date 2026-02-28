

import 'package:equatable/equatable.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';

abstract class CafeDetailsState extends Equatable {
  const CafeDetailsState();

  @override
  List<Object?> get props => [];
}

class CafeDetailsInitial extends CafeDetailsState {
  const CafeDetailsInitial();
}

class CafeDetailsLoading extends CafeDetailsState {
  const CafeDetailsLoading();
}

class CafeDetailsLoaded extends CafeDetailsState {
  final CafeDetailsResult data;
  const CafeDetailsLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class CafeDetailsError extends CafeDetailsState {
  final String message;
  const CafeDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}