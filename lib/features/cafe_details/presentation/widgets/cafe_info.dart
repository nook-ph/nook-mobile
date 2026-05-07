import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/utils/maps_directions_launcher.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_location_map_preview.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CafeInfo extends StatelessWidget {
  const CafeInfo({super.key, required this.cafe});

  final CafeDetailsResult? cafe;

  static const TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 15,
    color: Color(0xFF848685),
  );

  String _normalizeCategory(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<TagEntity> _tagsByCategory(List<TagEntity> tags, List<String> aliases) {
    final normalizedAliases = aliases.map(_normalizeCategory).toSet();
    return tags.where((tag) {
      final category = _normalizeCategory(tag.category ?? '');
      return normalizedAliases.contains(category);
    }).toList();
  }

  bool _isPaymentLikeTag(TagEntity tag) {
    final text = tag.name.toLowerCase();
    return text.contains('cash') ||
        text.contains('card') ||
        text.contains('credit') ||
        text.contains('debit') ||
        text.contains('wallet') ||
        text.contains('gcash') ||
        text.contains('maya');
  }

  String _mapAppMetadata(MapsAppChoice? preferredApp, TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) {
      if (preferredApp == MapsAppChoice.googleMaps) return 'google_maps';
      return 'apple_maps';
    }
    return 'google_maps_fallback_chain';
  }

  Future<void> _onGetDirectionsTap(BuildContext context) async {
    final details = cafe?.cafeDetails;
    final platform = Theme.of(context).platform;
    final analytics = sl<AnalyticsService>();
    final cafeId = details?.id;
    debugPrint(
      '[Directions] Tap detected | platform=$platform | '
      'hasDetails=${details != null}',
    );
    if (details == null || cafeId == null || cafeId.isEmpty) {
      debugPrint('[Directions] Aborted: cafe details are null');
      _showDirectionsError(context, 'Cafe details are not available yet.');
      return;
    }

    final lat = details.lat;
    final lng = details.lng;
    debugPrint(
      '[Directions] Coordinates received | lat=$lat lng=$lng | '
      'name="${details.name}" locationLabel="${details.locationLabel}"',
    );
    if (!MapsDirectionsLauncher.hasValidCoordinates(lat, lng)) {
      debugPrint('[Directions] Aborted: invalid coordinates');
      _showDirectionsError(
        context,
        'Directions are unavailable for this cafe right now.',
      );
      return;
    }

    MapsAppChoice? preferredApp;
    if (platform == TargetPlatform.iOS) {
      debugPrint('[Directions] iOS detected, showing app chooser');
      preferredApp = await _showIosMapsChooser(context);
      debugPrint('[Directions] iOS chooser result: $preferredApp');
      if (preferredApp == null) {
        debugPrint('[Directions] Aborted: user dismissed iOS app chooser');
        return;
      }
    }

    final mapAppMeta = _mapAppMetadata(preferredApp, platform);
    unawaited(
      analytics.track(
        cafeId,
        AnalyticsService.getDirections,
        metadata: {
          AnalyticsMetadataKeys.latitude: lat,
          AnalyticsMetadataKeys.longitude: lng,
          AnalyticsMetadataKeys.mapApp: mapAppMeta,
          AnalyticsMetadataKeys.screen: 'cafe_details',
        },
      ),
    );

    final label = details.name.isNotEmpty
        ? details.name
        : details.locationLabel;
    debugPrint(
      '[Directions] Launch request | lat=$lat lng=$lng | '
      'label="$label" preferredApp=$preferredApp',
    );
    final launched = await MapsDirectionsLauncher.launchDirections(
      lat: lat,
      lng: lng,
      label: label,
      platform: platform,
      preferredApp: preferredApp,
    );
    debugPrint('[Directions] Launch result: launched=$launched');

    if (!context.mounted) {
      debugPrint('[Directions] Context unmounted after launch attempt');
      return;
    }

    if (launched) {
      return;
    }

    debugPrint('[Directions] Launch failed, showing error snackbar');
    _showDirectionsError(context, 'Unable to open map directions.');
  }

  Future<MapsAppChoice?> _showIosMapsChooser(BuildContext context) {
    return showModalBottomSheet<MapsAppChoice>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewPaddingOf(sheetContext).bottom;
        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF868686),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Center(
                      child: Text(
                        'Open Directions With',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 32,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: Color(0xFFAEAEB2),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      leading: const Icon(
                        CupertinoIcons.map,
                        color: Color(0xFF1C1C1E),
                      ),
                      title: const Text(
                        'Google Maps',
                        style: TextStyle(
                          fontSize: 17,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: Color(0xFF8E8E93),
                      ),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(MapsAppChoice.googleMaps),
                    ),
                    const Divider(height: 1, indent: 12),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      leading: const Icon(
                        CupertinoIcons.location_solid,
                        color: Color(0xFF1C1C1E),
                      ),
                      title: const Text(
                        'Apple Maps',
                        style: TextStyle(
                          fontSize: 17,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: Color(0xFF8E8E93),
                      ),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(MapsAppChoice.appleMaps),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDirectionsError(BuildContext context, String message) {
    showPrimaryToast(context, message);
  }

  String? _extractHandle(String rawValue) {
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

  Uri? _toWebUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    if (trimmed.startsWith('www.')) {
      return Uri.tryParse('https://$trimmed');
    }
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
      default:
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
      showPrimaryToast(context, 'Unable to open $platform link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTags = cafe?.cafeDetails.tags ?? const <TagEntity>[];

    final amenities = _tagsByCategory(allTags, const ['amenities', 'amenity']);

    var bestFor = _tagsByCategory(allTags, const [
      'best_for',
      'best for',
      'bestfor',
      'best',
    ]);

    var paymentOptions = _tagsByCategory(allTags, const [
      'payment_options',
      'payment option',
      'payment options',
      'payment',
      'payments',
      'accepted payment',
      'accepted payments',
    ]);

    if (paymentOptions.isEmpty) {
      paymentOptions = allTags.where(_isPaymentLikeTag).toList();
    }

    if (bestFor.isEmpty) {
      final categorized = <String>{
        ...amenities.map((t) => t.id),
        ...paymentOptions.map((t) => t.id),
      };
      bestFor = allTags.where((t) => !categorized.contains(t.id)).toList();
    }

    final socialLinks = cafe?.cafeDetails.socialLinks ?? {};
    final address = cafe?.cafeDetails.address ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),

          const Gap(16),

          //amenities
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AMENITIES', style: _sectionTitleStyle),

              const Gap(12),

              if (amenities.isEmpty)
                const Text(
                  'No amenities listed',
                  style: TextStyle(fontSize: 15, color: Color(0xFF848685)),
                )
              else
                Column(
                  children: amenities.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tag = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == amenities.length - 1 ? 0 : 18,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            resolveTagIcon(tag.name) ?? Icons.circle_outlined,
                          ),
                          const Gap(18),
                          Expanded(
                            child: Text(
                              tag.name,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF848685),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          const Gap(28),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          const Gap(28),

          //best for
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BEST FOR', style: _sectionTitleStyle),

              const Gap(12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: bestFor.isEmpty
                    ? const [_BestForTag(label: 'No tags available')]
                    : bestFor
                          .map(
                            (tag) => _BestForTag(
                              label: tag.name,
                              icon: resolveTagIcon(tag.name),
                            ),
                          )
                          .toList(),
              ),
            ],
          ),

          const Gap(28),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          const Gap(28),

          //accepted payments
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ACCEPTED PAYMENTS', style: _sectionTitleStyle),

              const Gap(18),

              if (paymentOptions.isEmpty)
                const Text(
                  'No payment options listed',
                  style: TextStyle(fontSize: 15, color: Color(0xFF848685)),
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: paymentOptions
                      .map(
                        (payment) => _PaymentType(
                          icon:
                              resolveTagIcon(payment.name) ??
                              Icons.circle_outlined,
                          label: payment.name,
                        ),
                      )
                      .toList(),
                ),
            ],
          ),

          const Gap(28),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          const Gap(28),

          //location & contacts
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LOCATION & CONTACTS', style: _sectionTitleStyle),

              const Gap(16),

              Builder(
                builder: (context) {
                  final details = cafe?.cafeDetails;
                  if (details != null &&
                      MapsDirectionsLauncher.hasValidCoordinates(
                        details.lat,
                        details.lng,
                      )) {
                    return CafeLocationMapPreview(
                      lat: details.lat,
                      lng: details.lng,
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/Frame 181(1).png',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),

              const Gap(16),

              Text(
                address,
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),

              const Gap(10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _onGetDirectionsTap(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.black,
                    size: 18,
                  ),
                  label: const Text(
                    'Get Directions',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const Gap(16),

              if (socialLinks.isNotEmpty)
                Wrap(
                  spacing: 18,
                  children: [
                    if ((socialLinks['instagram']?.toString().isNotEmpty ??
                        false))
                      GestureDetector(
                        onTap: () => _openSocialLink(
                          context,
                          platform: 'instagram',
                          rawValue: socialLinks['instagram']?.toString(),
                        ),
                        child: PhosphorIcon(
                          PhosphorIcons.instagramLogo(
                            PhosphorIconsStyle.regular,
                          ),
                          size: 32,
                          color: const Color(0xFF848685),
                        ),
                      ),
                    if ((socialLinks['facebook']?.toString().isNotEmpty ??
                        false))
                      GestureDetector(
                        onTap: () => _openSocialLink(
                          context,
                          platform: 'facebook',
                          rawValue: socialLinks['facebook']?.toString(),
                        ),
                        child: PhosphorIcon(
                          PhosphorIcons.facebookLogo(
                            PhosphorIconsStyle.regular,
                          ),
                          size: 32,
                          color: const Color(0xFF848685),
                        ),
                      ),
                    if ((socialLinks['tiktok']?.toString().isNotEmpty ?? false))
                      GestureDetector(
                        onTap: () => _openSocialLink(
                          context,
                          platform: 'tiktok',
                          rawValue: socialLinks['tiktok']?.toString(),
                        ),
                        child: Icon(
                          PhosphorIcons.tiktokLogo(
                            PhosphorIconsStyle.regular,
                          ),
                          size: 32.0,
                          color: const Color(0xFF848685),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BestForTag extends StatelessWidget {
  const _BestForTag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF868584)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFF868584)),
            const Gap(4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF868584),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentType extends StatelessWidget {
  const _PaymentType({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Color(0xFF848685)),
        Gap(4),
        Text(label, style: TextStyle(fontSize: 15, color: Color(0xFF848685))),
      ],
    );
  }
}
