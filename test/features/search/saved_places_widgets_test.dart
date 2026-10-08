import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/presentation/cubit/place_search_cubit.dart';
import 'package:nook/features/search/presentation/cubit/saved_places_cubit.dart';
import 'package:nook/features/search/presentation/pages/saved_place_editor_page.dart';
import 'package:nook/features/search/presentation/widgets/search_option_row.dart';
import 'package:nook/features/search/presentation/widgets/search_origin_sheet.dart';

import 'place_search_fakes.dart';

const _home = SavedPlace(
  id: 'h',
  kind: SavedPlaceKind.home,
  label: 'Home',
  address: 'Lahug, Cebu City',
  lat: 10.33,
  lng: 123.9,
);

void main() {
  Future<void> setUpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('"Search near" sheet: saved places', () {
    late SearchOriginChoice? closedWith;
    late List<SavedPlaceKind> editorOpenedFor;

    Future<void> open(
      WidgetTester tester, {
      required FakeSavedPlacesRepository repo,
      SearchOrigin? current,
      FakePlaceSearchRepository? search,
      SavedPlace? Function(SavedPlaceKind kind)? editorResult,
    }) async {
      await setUpScreen(tester);
      closedWith = null;
      editorOpenedFor = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  closedWith = await showSearchOriginSheet(
                    context,
                    current: current,
                    currentLocationLabel: null,
                    recentPlaces: const [],
                    search: PlaceSearchCubit(
                      repository: search ?? FakePlaceSearchRepository(),
                      places: Future.value(SearchPlaceIndex.empty),
                      debounce: Duration.zero,
                    ),
                    saved: SavedPlacesCubit(repo)..load(),
                    openEditor: (_, {place, required kind}) async {
                      editorOpenedFor.add(kind);
                      return editorResult?.call(kind);
                    },
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('Home and School or work show unset, with Add a place', (
      tester,
    ) async {
      await open(tester, repo: FakeSavedPlacesRepository());
      expect(find.text('Saved places'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('School or work'), findsOneWidget);
      expect(
        find.text('Set it once, search near it anytime'),
        findsNWidgets(2),
      );
      expect(find.text('Add a place'), findsOneWidget);
    });

    testWidgets('set my home: the editor opens, and the new Home is used', (
      tester,
    ) async {
      await open(
        tester,
        repo: FakeSavedPlacesRepository(),
        editorResult: (_) => _home,
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(editorOpenedFor, [SavedPlaceKind.home]);
      final choice = closedWith as UsePlace;
      expect(choice.place, _home.toOrigin());
      expect(choice.justSaved, isTrue);
    });

    testWidgets('one tap on a saved place searches near it', (tester) async {
      await open(tester, repo: FakeSavedPlacesRepository(places: [_home]));
      expect(find.text('Lahug, Cebu City'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect((closedWith as UsePlace).place.label, 'Home');
      expect(editorOpenedFor, isEmpty);
    });

    testWidgets('the place in use is ticked', (tester) async {
      await open(
        tester,
        repo: FakeSavedPlacesRepository(places: [_home]),
        current: _home.toOrigin(),
      );
      // One tick, on Home: Current location is not in use.
      final tick = find.byIcon(LucideIcons.check);
      expect(tick, findsOneWidget);
      Element rowOf(Finder f) => tester.element(
        find.ancestor(of: f, matching: find.byType(SearchOptionRow)),
      );
      expect(rowOf(tick), rowOf(find.text('Home')));
    });

    testWidgets('⋯ then Delete, confirmed, removes the place', (tester) async {
      final repo = FakeSavedPlacesRepository(places: [_home]);
      await open(tester, repo: repo);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is SearchIconButton && w.label == 'Edit or delete Home',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Home?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(repo.places, isEmpty);
      expect(
        find.text('Set it once, search near it anytime'),
        findsNWidgets(2),
      );
      expect(closedWith, isNull);
    });

    testWidgets('at the cap, Add a place gives way to a note', (tester) async {
      await open(
        tester,
        repo: FakeSavedPlacesRepository(
          places: [
            for (var i = 0; i < ISavedPlacesRepository.maxPlaces; i++)
              SavedPlace(
                id: '$i',
                kind: SavedPlaceKind.custom,
                label: 'Place $i',
                lat: 10,
                lng: 123,
              ),
          ],
        ),
      );
      await tester.scrollUntilVisible(
        find.textContaining('the most you can keep'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Add a place'), findsNothing);
    });

    testWidgets('a guest is asked to sign in', (tester) async {
      await open(tester, repo: FakeSavedPlacesRepository(canSave: false));
      expect(find.text('Home'), findsNothing);
      await tester.tap(find.text('Save Home and School or work'));
      await tester.pumpAndSettle();
      expect(closedWith, isA<SignInToSave>());
    });

    testWidgets('search near SM Seaside: the map’s place, with the credit', (
      tester,
    ) async {
      await open(
        tester,
        repo: FakeSavedPlacesRepository(places: [_home]),
        search: FakePlaceSearchRepository(
          answers: {
            'SM Seaside': [
              landmark(
                'SM Seaside City Cebu',
                subtitle: 'Mambaling, Cebu City',
              ),
            ],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'SM Seaside');
      await tester.pumpAndSettle();
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      await tester.tap(find.text('SM Seaside City Cebu'));
      await tester.pumpAndSettle();
      expect((closedWith as UsePlace).place.label, 'SM Seaside City Cebu');
    });

    testWidgets('map search down: says so, and still offers the map pin', (
      tester,
    ) async {
      await open(
        tester,
        repo: FakeSavedPlacesRepository(),
        search: FakePlaceSearchRepository(fail: true),
      );
      await tester.enterText(find.byType(TextField), 'USC Talamban');
      await tester.pumpAndSettle();
      expect(find.text('Place search is slow right now'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Pick on the map'), findsOneWidget);
    });

    testWidgets('the keyboard Search key takes the first place', (
      tester,
    ) async {
      await open(
        tester,
        repo: FakeSavedPlacesRepository(),
        search: FakePlaceSearchRepository(
          answers: {
            'SM Seaside': [landmark('SM Seaside City Cebu')],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'SM Seaside');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect((closedWith as UsePlace).place.label, 'SM Seaside City Cebu');
    });

    testWidgets('typing "hom" finds the saved Home first', (tester) async {
      await open(tester, repo: FakeSavedPlacesRepository(places: [_home]));
      await tester.enterText(find.byType(TextField), 'hom');
      await tester.pumpAndSettle();
      expect(find.text('Saved places'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect((closedWith as UsePlace).place, _home.toOrigin());
    });
  });

  group('saved place editor', () {
    late SavedPlace? popped;
    late bool didPop;

    Future<SavedPlacesCubit> open(
      WidgetTester tester, {
      required FakeSavedPlacesRepository repo,
      SavedPlaceKind kind = SavedPlaceKind.custom,
      SavedPlace? place,
      FakePlaceSearchRepository? search,
      ({double lat, double lng})? position,
    }) async {
      await setUpScreen(tester);
      popped = null;
      didPop = false;
      final cubit = SavedPlacesCubit(repo);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<SavedPlace>(
                  MaterialPageRoute(
                    builder: (_) => SavedPlaceEditorPage(
                      cubit: cubit,
                      kind: kind,
                      place: place,
                      search: search ?? FakePlaceSearchRepository(),
                      places: Future.value(SearchPlaceIndex.empty),
                      mapPreview: (_, _) =>
                          const ColoredBox(color: Colors.grey),
                      currentPosition: () async => position,
                    ),
                  ),
                );
                didPop = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return cubit;
    }

    testWidgets('Save with nothing filled in says what is missing', (
      tester,
    ) async {
      final repo = FakeSavedPlacesRepository();
      await open(tester, repo: repo);
      expect(find.text('Add a place'), findsOneWidget);
      await tester.tap(find.text('Save place'));
      await tester.pumpAndSettle();
      expect(find.text('Give it a name.'), findsOneWidget);
      expect(
        find.text('Search for the place, use where you are, or pin it.'),
        findsOneWidget,
      );
      expect(repo.places, isEmpty);
    });

    testWidgets('name + searched place saves a custom place', (tester) async {
      final repo = FakeSavedPlacesRepository();
      await open(
        tester,
        repo: repo,
        search: FakePlaceSearchRepository(
          answers: {
            'Mabolo': [
              landmark('Mabolo Church', subtitle: 'Mabolo, Cebu City'),
            ],
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Lola’s house');
      await tester.tap(find.text('Search for a place'));
      await tester.pumpAndSettle();
      expect(find.text('Find a place'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Mabolo');
      // The map is asked once typing pauses.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mabolo Church'));
      await tester.pumpAndSettle();
      expect(find.text('Mabolo Church, Mabolo, Cebu City'), findsOneWidget);
      await tester.tap(find.text('Save place'));
      await tester.pumpAndSettle();
      expect(didPop, isTrue);
      expect(popped?.label, 'Lola’s house');
      expect(repo.places.single.address, 'Mabolo Church, Mabolo, Cebu City');
    });

    testWidgets('Set home with current location', (tester) async {
      final repo = FakeSavedPlacesRepository();
      final search = FakePlaceSearchRepository()
        ..reverseAnswer = landmark(
          'Ayala Center Cebu',
          subtitle: 'Cebu Business Park',
        );
      await open(
        tester,
        repo: repo,
        kind: SavedPlaceKind.home,
        search: search,
        position: (lat: 10.318, lng: 123.905),
      );
      expect(find.text('Set Home'), findsOneWidget);
      expect(find.text('Name'), findsNothing);
      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();
      expect(
        find.text('Near Ayala Center Cebu, Cebu Business Park'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save as Home'));
      await tester.pumpAndSettle();
      expect(popped?.kind, SavedPlaceKind.home);
      expect(repo.places.single.lat, 10.318);
    });

    testWidgets('location off: explains instead of saving', (tester) async {
      await open(
        tester,
        repo: FakeSavedPlacesRepository(),
        kind: SavedPlaceKind.work,
      );
      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your location is off.'), findsOneWidget);
    });

    testWidgets('a failed save says so and keeps the form', (tester) async {
      final repo = FakeSavedPlacesRepository()..failSave = true;
      await open(tester, repo: repo, kind: SavedPlaceKind.home, place: _home);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t save. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(didPop, isFalse);
    });

    testWidgets('Delete place asks first, then removes it', (tester) async {
      final repo = FakeSavedPlacesRepository(places: [_home]);
      await open(tester, repo: repo, kind: SavedPlaceKind.home, place: _home);
      expect(find.text('Change Home'), findsOneWidget);
      await tester.tap(find.text('Delete place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.places, isEmpty);
      expect(didPop, isTrue);
      expect(popped, isNull);
    });
  });
}
