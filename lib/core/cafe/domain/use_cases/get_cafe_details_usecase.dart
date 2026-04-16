import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetCafeDetailsUseCase {
  final ICafeRepository repository;

  GetCafeDetailsUseCase(this.repository);

  Future<CafeBundle> call(String cafeId) async {
    final bundle = await repository.getCafeBundleById(
      cafeId,
      includeMenu: true,
      includeReviews: true,
    );

    final latestReviews = bundle.reviews == null
        ? null
        : bundle.reviews!.take(3).toList();

    final menuHighlights = bundle.menu == null
        ? null
        : bundle.menu!.where((item) => item.isHighlight).toList();

    return bundle.copyWith(menu: menuHighlights, reviews: latestReviews);
  }
}
