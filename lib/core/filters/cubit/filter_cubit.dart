import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';

class FilterCubit extends Cubit<CafeFilter> {
  FilterCubit() : super(const CafeFilter());

  void setSingleTag(String tag) {
    emit(
      state.copyWith(
        tagNames: {tag},
        query: null, // Clear query on tag handoff as per requirements
      ),
    );
  }

  void setFilter(CafeFilter filter) {
    emit(filter);
  }

  void reset() {
    emit(const CafeFilter());
  }
}
