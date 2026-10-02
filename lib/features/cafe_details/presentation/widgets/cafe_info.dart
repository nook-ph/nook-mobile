import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/maps_directions_launcher.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_tag_groups.dart';
import 'package:nook/features/cafe_details/presentation/utils/launch_cafe_directions.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_location_map_preview.dart';
import 'package:nook/injection_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Amenities as a two-column icon grid, then "Best for" chips.
///
/// These are the reason people open Nook, so they sit above the fold. Either
/// half is left out when the listing has nothing for it; the page skips the
/// whole section when both are empty (see [hasContent]).
class CafeAmenitiesSection extends StatelessWidget {
  const CafeAmenitiesSection({super.key, required this.groups});

  final CafeTagGroups groups;

  static bool hasContent(CafeTagGroups groups) =>
      groups.amenities.isNotEmpty || groups.bestFor.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final amenities = groups.amenities;
    final bestFor = groups.bestFor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CafeDetailsTokens.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (amenities.isNotEmpty) ...[
            const CafeSectionTitle('Amenities'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final cell = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: 12,
                  children: [
                    for (final tag in amenities)
                      SizedBox(
                        width: cell,
                        child: _AmenityCell(tag: tag),
                      ),
                  ],
                );
              },
            ),
          ],
          if (amenities.isNotEmpty && bestFor.isNotEmpty)
            const SizedBox(height: 20),
          if (bestFor.isNotEmpty) ...[
            const CafeSectionTitle('Best for'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in bestFor) _BestForChip(label: tag.name),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AmenityCell extends StatelessWidget {
  const _AmenityCell({required this.tag});

  final TagEntity tag;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: CafeDetailsTokens.tint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            resolveTagIcon(tag.name) ?? Icons.circle_outlined,
            size: 18,
            color: CafeDetailsTokens.brand,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tag.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: CafeDetailsTokens.ink),
          ),
        ),
      ],
    );
  }
}

class _BestForChip extends StatelessWidget {
  const _BestForChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CafeDetailsTokens.border),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: CafeDetailsTokens.ink),
      ),
    );
  }
}

/// "Hours & location": the map, then plain icon rows for hours (which opens
/// to the week), address and accepted payments, then the cafe's socials.
class CafeHoursLocationSection extends StatelessWidget {
  const CafeHoursLocationSection({
    super.key,
    required this.cafe,
    required this.groups,
  });

  final CafeDetailsResult cafe;
  final CafeTagGroups groups;

  static String? _extractHandle(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return null;

    var value = trimmed;
    if (!value.contains('://') && value.startsWith('www.')) {
      value = 'https://$value';
    }

    final parsed = Uri.tryParse(value);
    String? handle;
    if (parsed != null &&
        (parsed.hasScheme || parsed.host.isNotEmpty) &&
        parsed.pathSegments.isNotEmpty) {
      handle = parsed.pathSegments.lastWhere(
        (segment) => segment.trim().isNotEmpty,
        orElse: () => '',
      );
      if (handle.isEmpty && parsed.queryParameters.isNotEmpty) {
        handle = parsed.queryParameters['id'];
      }
    } else if (trimmed.contains('/')) {
      handle = trimmed.split('/').last;
    } else {
      handle = trimmed;
    }

    final normalized = handle?.replaceFirst('@', '').trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  static Uri? _toWebUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return parsed;
    if (trimmed.startsWith('www.')) return Uri.tryParse('https://$trimmed');
    if (!trimmed.contains(' ') && trimmed.contains('.')) {
      return Uri.tryParse('https://$trimmed');
    }
    return null;
  }

  Future<void> _openSocialLink(
    BuildContext context, {
    required String platform,
    required String? rawValue,
  }) async {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return;

    final handle = _extractHandle(value);
    Uri? appUri;
    Uri? webUri = _toWebUri(value);

    switch (platform) {
      case 'instagram':
        if (handle != null) {
          appUri = Uri.parse('instagram://user?username=$handle');
          webUri ??= Uri.parse('https://www.instagram.com/$handle');
        }
        break;
      case 'facebook':
        final originalWebUri = _toWebUri(value);
        if (originalWebUri != null) {
          appUri = Uri.parse(
            'facebook://facewebmodal/f?href=${Uri.encodeComponent(originalWebUri.toString())}',
          );
          webUri = originalWebUri;
        } else if (handle != null) {
          final webProfile = Uri.parse('https://www.facebook.com/$handle');
          appUri = Uri.parse(
            'facebook://facewebmodal/f?href=${Uri.encodeComponent(webProfile.toString())}',
          );
          webUri ??= webProfile;
        }
        break;
      case 'tiktok':
        if (handle != null) {
          appUri = Uri.parse('tiktok://user/@$handle');
          webUri ??= Uri.parse('https://www.tiktok.com/@$handle');
        }
        break;
    }

    var launched = false;
    if (appUri != null && await canLaunchUrl(appUri)) {
      launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
    }

    if (!launched && webUri != null && await canLaunchUrl(webUri)) {
      launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    if (!launched && context.mounted) {
      final name = platform[0].toUpperCase() + platform.substring(1);
      showPrimaryToast(context, 'Unable to open $name link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = cafe.cafeDetails;
    final address = details.address.trim();
    final payments = groups.payments;
    final hasMap = MapsDirectionsLauncher.hasValidCoordinates(
      details.lat,
      details.lng,
    );
    final status = CafeOpenStatus.resolve(
      details.operatingHours,
      DateTime.now(),
    );

    final socials = <(String, IconData)>[
      ('instagram', PhosphorIcons.instagramLogo()),
      ('facebook', PhosphorIcons.facebookLogo()),
      ('tiktok', PhosphorIcons.tiktokLogo()),
    ].where((s) => details.socialLinks[s.$1]?.toString().isNotEmpty ?? false);

    final rows = <Widget>[
      // A listing with no hours makes no open-or-closed claim: no row.
      if (status.hasAnyHours)
        _HoursRow(
          cafeId: details.id,
          operatingHours: details.operatingHours,
          status: status,
        ),
      if (address.isNotEmpty)
        CafeDistanceBuilder(
          lat: details.lat,
          lng: details.lng,
          builder: (context, distance) => _InfoRow(
            icon: PhosphorIcons.mapPin(),
            title: address,
            subtitle: distance == null ? null : '$distance from you',
          ),
        ),
      if (payments.isNotEmpty)
        _InfoRow(
          icon: PhosphorIcons.money(),
          title: payments.map((p) => p.name).join(', '),
          subtitle: 'Payments accepted',
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CafeDetailsTokens.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CafeSectionTitle('Hours & location'),
          const SizedBox(height: 12),
          // The map is the way to directions from here; the pinned bar holds
          // the button, so there is no second one under the address.
          Semantics(
            button: hasMap,
            label: 'Map. Opens directions.',
            child: AdaptiveTap(
              onTap: () => launchCafeDirections(context, cafe),
              borderRadius: BorderRadius.circular(12),
              child: hasMap
                  ? AbsorbPointer(
                      child: CafeLocationMapPreview(
                        lat: details.lat,
                        lng: details.lng,
                        rating: details.rating,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/Frame 181(1).png',
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: CafeDetailsTokens.border,
              ),
            rows[i],
          ],
          if (socials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final social in socials)
                  _SocialButton(
                    icon: social.$2,
                    label: social.$1,
                    onTap: () => _openSocialLink(
                      context,
                      platform: social.$1,
                      rawValue: details.socialLinks[social.$1]?.toString(),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final note = subtitle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CafeDetailsTokens.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    color: CafeDetailsTokens.ink,
                  ),
                ),
                if (note != null)
                  Text(
                    note,
                    style: textTheme.bodySmall?.copyWith(
                      color: CafeDetailsTokens.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's status and hours; tapping opens the whole week in place.
class _HoursRow extends StatefulWidget {
  const _HoursRow({
    required this.cafeId,
    required this.operatingHours,
    required this.status,
  });

  final String cafeId;
  final Map<String, dynamic> operatingHours;
  final CafeOpenStatus status;

  @override
  State<_HoursRow> createState() => _HoursRowState();
}

class _HoursRowState extends State<_HoursRow> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (!_expanded || widget.cafeId.isEmpty) return;
    unawaited(
      sl<AnalyticsService>().track(
        widget.cafeId,
        AnalyticsService.checkHours,
        metadata: {AnalyticsMetadataKeys.screen: 'cafe_details'},
      ),
    );
  }

  static String _dayLabel(String day) =>
      day[0].toUpperCase() + day.substring(1);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = widget.status;
    final hours = widget.operatingHours;
    final today = CafeOpenStatus.dayKey(DateTime.now());
    final todayRange = CafeOpenStatus.formatRange(hours, today);
    final detail = status.rowDetail;
    final statusColor = CafeDetailsTokens.statusLabel(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: _expanded ? 'Hide the week' : 'Show the week',
          child: AdaptiveTap(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.clock(),
                    size: 20,
                    color: CafeDetailsTokens.ink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: status.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                              if (detail != null) TextSpan(text: ' · $detail'),
                            ],
                          ),
                          style: textTheme.bodyLarge?.copyWith(
                            color: CafeDetailsTokens.ink,
                          ),
                        ),
                        Text(
                          todayRange == 'Closed'
                              ? 'Closed today'
                              : 'Today $todayRange',
                          style: textTheme.bodySmall?.copyWith(
                            color: CafeDetailsTokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? PhosphorIcons.caretUp()
                        : PhosphorIcons.caretDown(),
                    size: 18,
                    color: CafeDetailsTokens.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 12),
            child: Column(
              children: [
                for (final day in CafeOpenStatus.orderedDays)
                  _DayLine(
                    day: day == today
                        ? '${_dayLabel(day)} · Today'
                        : _dayLabel(day),
                    hours: CafeOpenStatus.formatRange(hours, day),
                    isToday: day == today,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayLine extends StatelessWidget {
  const _DayLine({
    required this.day,
    required this.hours,
    required this.isToday,
  });

  final String day;
  final String hours;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    final weight = isToday ? FontWeight.w600 : FontWeight.w400;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day,
              style: base?.copyWith(
                fontWeight: weight,
                color: isToday
                    ? CafeDetailsTokens.ink
                    : CafeDetailsTokens.muted,
              ),
            ),
          ),
          Text(
            hours,
            style: base?.copyWith(
              fontWeight: weight,
              color: CafeDetailsTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open $label',
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CafeDetailsTokens.border),
          ),
          child: Icon(icon, size: 20, color: CafeDetailsTokens.ink),
        ),
      ),
    );
  }
}
