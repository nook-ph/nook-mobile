import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/presentation/widgets/waitlist_cities.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/core/widgets/error/state_styles.dart';

/// Asks someone outside Cebu which city they want Nook in, logs it as
/// `city_waitlist_requested` with a matched city or `other` (see
/// [CityWaitlistSheet.analyticsCity]), and thanks them. Nothing is stored
/// and the typed text is never sent; the event is the count. The app has no reverse geocoder, so the user names the city.
Future<void> requestCityWaitlist(
  BuildContext context, {
  required String surface,
}) async {
  final city = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => const CityWaitlistSheet(),
  );
  final name = CityWaitlistSheet.clean(city ?? '');
  if (name.isEmpty) return;
  logAppEvent(
    CityWaitlistEvents.requested,
    properties: {
      'city': CityWaitlistSheet.analyticsCity(name),
      'surface': surface,
    },
  );
  if (context.mounted) {
    showPrimaryToast(context, CityWaitlistSheet.thanks);
  }
}

/// A field for the city, a few common answers to tap, and Send.
class CityWaitlistSheet extends StatefulWidget {
  const CityWaitlistSheet({super.key});

  static const title = 'Which city should Nook go to next?';
  static const message =
      'Nook covers Cebu for now. Tell us where you are and we will count it '
      'when we pick the next city.';
  static const sendLabel = 'Send';
  static const thanks = 'Thanks! Every request counts toward the next city.';

  /// Common answers, so most people tap instead of type.
  static const suggestions = [
    'Manila',
    'Davao',
    'Iloilo',
    'Bacolod',
    'Cagayan de Oro',
    'Baguio',
  ];

  static const maxLength = 60;

  /// Trimmed, single-spaced, at most [maxLength] characters.
  static String clean(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= maxLength ? text : text.substring(0, maxLength);
  }

  /// What goes to analytics for [city]: the canonical name when it matches
  /// a known city or area ([WaitlistCities], ignoring case, accents and
  /// spacing), else [other]. The typed text itself is never sent or stored:
  /// the field is free text, and a name, email, phone number or address
  /// typed into it must not leave the phone.
  static String analyticsCity(String city) =>
      WaitlistCities.match(clean(city)) ?? other;

  /// Logged for a typed answer that is not a known city or area.
  static const other = 'other';

  @override
  State<CityWaitlistSheet> createState() => _CityWaitlistSheetState();
}

class _CityWaitlistSheetState extends State<CityWaitlistSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final city = CityWaitlistSheet.clean(_controller.text);
    if (city.isEmpty) return;
    Navigator.of(context).pop(city);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = math.max(34.0, media.viewPadding.bottom);
    final canSend = CityWaitlistSheet.clean(_controller.text).isNotEmpty;

    return Padding(
      // Rides up with the keyboard.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: StateStyles.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: StateStyles.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              CityWaitlistSheet.title,
              textAlign: TextAlign.center,
              style: StateStyles.text(20, FontWeight.w600, StateStyles.ink),
            ),
            const SizedBox(height: 6),
            Text(
              CityWaitlistSheet.message,
              textAlign: TextAlign.center,
              style: StateStyles.text(14, FontWeight.w400, StateStyles.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.send,
              maxLength: CityWaitlistSheet.maxLength,
              onSubmitted: (_) => _send(),
              style: StateStyles.text(14, FontWeight.w400, StateStyles.ink),
              decoration: InputDecoration(
                hintText: 'Your city',
                counterText: '',
                filled: true,
                fillColor: StateStyles.tint,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final city in CityWaitlistSheet.suggestions)
                  _CityChip(
                    label: city,
                    selected: _controller.text == city,
                    onTap: () => _controller.value = TextEditingValue(
                      text: city,
                      selection: TextSelection.collapsed(offset: city.length),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              enabled: canSend,
              child: AdaptiveTap(
                onTap: canSend ? _send : null,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: canSend ? StateStyles.brand : StateStyles.tint,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    CityWaitlistSheet.sendLabel,
                    style: StateStyles.text(
                      14,
                      FontWeight.w500,
                      canSend ? StateStyles.surface : StateStyles.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? StateStyles.brand : StateStyles.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? StateStyles.brand : StateStyles.border,
            ),
          ),
          child: Text(
            label,
            style: StateStyles.text(
              13,
              FontWeight.w500,
              selected ? StateStyles.surface : StateStyles.ink,
            ),
          ),
        ),
      ),
    );
  }
}
