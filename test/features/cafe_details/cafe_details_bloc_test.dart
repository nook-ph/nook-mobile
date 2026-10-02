import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_event.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';

class _BundleRepository implements ICafeRepository {
  _BundleRepository(this.menu);

  final List<MenuItem> menu;

  @override
  Future<CafeBundle> getCafeBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  }) async => CafeBundle(
    details: CafeDetails(
      id: cafeId,
      createdAt: DateTime(2025),
      name: 'Volte',
      description: '',
      address: '',
      neighborhood: 'Lahug',
      lat: 10.3,
      lng: 123.9,
      rating: 4.5,
      reviewCount: 3,
      isNew: false,
    ),
    menu: menu,
    reviews: const [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

MenuItem _item(String id, {bool highlight = false}) => MenuItem(
  id: id,
  cafeId: 'cafe-1',
  name: 'Item $id',
  price: 120,
  isHighlight: highlight,
);

Future<CafeDetailsLoaded> _load(List<MenuItem> menu) async {
  final bloc = CafeDetailsBloc(
    getCafeDetailsUseCase: GetCafeDetailsUseCase(_BundleRepository(menu)),
  );
  addTearDown(bloc.close);
  bloc.add(const LoadCafeDetailsRequested(cafeId: 'cafe-1'));
  return await bloc.stream.firstWhere((s) => s is CafeDetailsLoaded)
      as CafeDetailsLoaded;
}

void main() {
  test('See all gets every menu item; the strip only the highlights', () async {
    final state = await _load([
      _item('a', highlight: true),
      _item('b'),
      _item('c', highlight: true),
      _item('d'),
    ]);

    expect(state.data.allMenuItems.map((i) => i.id), ['a', 'b', 'c', 'd']);
    expect(state.data.menuHighlights.map((i) => i.id), ['a', 'c']);
  });

  test('a menu with nothing highlighted still shows its first items', () async {
    final state = await _load([for (var i = 0; i < 8; i++) _item('$i')]);

    expect(state.data.allMenuItems, hasLength(8));
    expect(state.data.menuHighlights.map((i) => i.id), [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
    ]);
  });

  test('no menu at all shows no strip', () async {
    final state = await _load(const []);

    expect(state.data.menuHighlights, isEmpty);
    expect(state.data.allMenuItems, isEmpty);
  });
}
