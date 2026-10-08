import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/public_profile/presentation/cubit/profile_visibility_cubit.dart';

import '../../core/analytics/recording_analytics.dart';
import 'public_profile_fakes.dart';

void main() {
  test('turning the gallery off is logged once it saved', () async {
    final analytics = RecordingAnalytics.install(addTearDown);
    final cubit = ProfileVisibilityCubit(
      repository: FakePublicProfileRepository(),
    );
    addTearDown(cubit.close);

    expect(await cubit.setHighlightsPublic(false), isTrue);
    expect(analytics.propertiesOf('profile_visibility_changed'), {
      'public': false,
    });
  });

  test('a failed save is not logged', () async {
    final analytics = RecordingAnalytics.install(addTearDown);
    final repo = FakePublicProfileRepository()..writeFailure = Exception('x');
    final cubit = ProfileVisibilityCubit(repository: repo);
    addTearDown(cubit.close);

    expect(await cubit.setHighlightsPublic(false), isFalse);
    expect(analytics.events, isEmpty);
  });

  test('a load that finishes after sign-out is dropped', () async {
    final cubit = ProfileVisibilityCubit(
      repository: FakePublicProfileRepository(),
    );
    addTearDown(cubit.close);
    final loading = cubit.load();
    cubit.clear();
    await loading;
    expect(cubit.state, const ProfileVisibilityState());
  });
}
