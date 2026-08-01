import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/maps_directions_launcher.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/utils/launch_cafe_directions.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_location_map_preview.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CafeInfo extends StatelessWidget {
  const CafeInfo({super.key, required this.cafe});

  final CafeDetailsResult? cafe;

  TextStyle? _sectionTitleStyle(BuildContext context) =>
      context.textTheme.bodyLarge?.copyWith(color: const Color(0xFF767574));

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

  Future<void> _onGetDirectionsTap(BuildContext context) {
    return launchCafeDirections(context, cafe);
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
          Text(
            'Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const Gap(16),

          // Amenities
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AMENITIES', style: _sectionTitleStyle(context)),
              const Gap(12),
              if (amenities.isEmpty)
                Text(
                  'No amenities listed',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF767574),
                  ),
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
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: const Color(0xFF767574)),
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

          // Best For
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BEST FOR', style: _sectionTitleStyle(context)),
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
          // Accepted Payments — the whole section goes when there is nothing
          // in it, divider included. It used to render a heading followed by
          // "No payment options listed", spending a full section of a long
          // page to tell the user nothing.
          if (paymentOptions.isNotEmpty) ...[
            const Gap(28),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
            const Gap(28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACCEPTED PAYMENTS', style: _sectionTitleStyle(context)),
                const Gap(18),
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
          ],
          const Gap(28),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
          const Gap(28),

          // Location & Contacts
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LOCATION & CONTACTS', style: _sectionTitleStyle(context)),
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
                      rating: details.rating,
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
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.black),
              ),
              const Gap(10),
              SizedBox(
                width: double.infinity,
                child: AdaptiveOutlinedButton(
                  onPressed: () => _onGetDirectionsTap(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(
                      color: context.colorScheme.border,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.black,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Get Directions',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(16),

              // Social Links with AdaptiveTap
              if (socialLinks.isNotEmpty)
                Wrap(
                  spacing: 18,
                  children: [
                    if (socialLinks['instagram']?.toString().isNotEmpty ??
                        false)
                      AdaptiveTap(
                        onTap: () => _openSocialLink(
                          context,
                          platform: 'instagram',
                          rawValue: socialLinks['instagram']?.toString(),
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: PhosphorIcon(
                            PhosphorIcons.instagramLogo(
                              PhosphorIconsStyle.regular,
                            ),
                            size: 32,
                            color: const Color(0xFF767574),
                          ),
                        ),
                      ),
                    if (socialLinks['facebook']?.toString().isNotEmpty ?? false)
                      AdaptiveTap(
                        onTap: () => _openSocialLink(
                          context,
                          platform: 'facebook',
                          rawValue: socialLinks['facebook']?.toString(),
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: PhosphorIcon(
                            PhosphorIcons.facebookLogo(
                              PhosphorIconsStyle.regular,
                            ),
                            size: 32,
                            color: const Color(0xFF767574),
                          ),
                        ),
                      ),
                    if (socialLinks['tiktok']?.toString().isNotEmpty ?? false)
                      AdaptiveTap(
                        onTap: () => _openSocialLink(
                          context,
                          platform: 'tiktok',
                          rawValue: socialLinks['tiktok']?.toString(),
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            PhosphorIcons.tiktokLogo(
                              PhosphorIconsStyle.regular,
                            ),
                            size: 32.0,
                            color: const Color(0xFF767574),
                          ),
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
        // Border stays light — it's decoration. The label and icon carry the
        // meaning, so they move to a tone that clears WCAG AA on white
        // (#868584 measured 3.66:1, under the 4.5:1 needed for body text).
        border: Border.all(color: const Color(0xFF868584)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFF767574)),
            const Gap(4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF767574),
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
        Icon(icon, color: const Color(0xFF767574)),
        const Gap(4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF767574)),
        ),
      ],
    );
  }
}
