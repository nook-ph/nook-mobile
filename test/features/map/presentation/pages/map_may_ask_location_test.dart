import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/preferences/home_location_prompt_store.dart';
import 'package:nook/core/preferences/location_prompt_store.dart';
import 'package:nook/features/map/presentation/pages/map_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('asks on a first visit nothing has asked before', () async {
    expect(
      await mapMayAskLocation(
        promptStore: LocationPromptStore(),
        homeStore: HomeLocationPromptStore(),
      ),
      isTrue,
    );
  });

  test('not once the system prompt was shown from anywhere', () async {
    final prompt = LocationPromptStore();
    await prompt.markRequested();
    expect(
      await mapMayAskLocation(
        promptStore: prompt,
        homeStore: HomeLocationPromptStore(),
      ),
      isFalse,
    );
  });

  test("not after Home's location offer was turned down", () async {
    final home = HomeLocationPromptStore();
    await home.markDismissed();
    expect(
      await mapMayAskLocation(
        promptStore: LocationPromptStore(),
        homeStore: home,
      ),
      isFalse,
    );
  });
}
