import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/filters/coffee_tag_catalog.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_content.dart';

void main() {
  group('coffeeFilterLabels', () {
    test('none before the coffee migration', () {
      expect(coffeeFilterLabels(const []), isEmpty);
    });

    test('the tags that exist, in the contract order', () {
      expect(
        coffeeFilterLabels(const [
          'Matcha',
          'kapeng barako',
          'Espresso',
          'Philippine Beans',
          'Some later tag',
        ]),
        ['Espresso', 'Philippine Beans', 'Kapeng Barako', 'Matcha'],
      );
    });
  });

  group('CoffeeTagCatalog', () {
    test('publishes what the lookup found, once', () async {
      var calls = 0;
      final catalog = CoffeeTagCatalog(
        fetch: () async {
          calls++;
          return ['Pour-over', 'Cold Brew'];
        },
      );

      await catalog.ensureLoaded();
      await catalog.ensureLoaded();

      expect(catalog.available.value, ['Pour-over', 'Cold Brew']);
      expect(calls, 1);
    });

    test('a failed lookup offers nothing and is tried again', () async {
      var fail = true;
      final catalog = CoffeeTagCatalog(
        fetch: () async {
          if (fail) throw Exception('offline');
          return ['Matcha'];
        },
      );

      await catalog.ensureLoaded();
      expect(catalog.available.value, isEmpty);

      fail = false;
      await catalog.ensureLoaded();
      expect(catalog.available.value, ['Matcha']);
    });
  });

  group('map filter labels', () {
    test('dead chips are gone and coffee covers all nine tags', () {
      expect(kMapFilterBestForLabels, isNot(contains('Book Cafe')));
      expect(kMapFilterAmenityLabels, isNot(contains('Open 24 Hours')));
      expect(kMapFilterCoffeeLabels, contains('Kapeng Barako'));
      expect(kMapFilterCoffeeLabels, contains('Philippine Beans'));
      expect(kMapFilterCoffeeLabels, hasLength(9));
    });
  });
}
