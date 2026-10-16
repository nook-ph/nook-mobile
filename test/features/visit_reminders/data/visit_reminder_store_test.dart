import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/visit_reminders/data/visit_reminder_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('overlapping first reads make one install id', () async {
    final store = VisitReminderStore();
    final both = await Future.wait([store.installId(), store.installId()]);
    expect(both[0].id, both[1].id);
    expect(both.where((r) => r.created), hasLength(1));
    final later = await store.installId();
    expect(later, (id: both[0].id, created: false));
    expect(await VisitReminderStore().installId(), later);
  });
}
