import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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

  IconData? _iconFromTagName(String? tagName) {
    if (tagName == null || tagName.trim().isEmpty) {
      return null;
    }

    final normalized = tagName.trim().toLowerCase();

    switch (normalized) {
      case 'date spot':
        return PhosphorIcons.heart();
      case 'solo work / study':
        return PhosphorIcons.laptop();
      case 'group hangout':
        return PhosphorIcons.users();
      case 'book cafe':
        return PhosphorIcons.bookOpen();
      case 'late night':
        return PhosphorIcons.moon();
      case 'quick coffee':
        return PhosphorIcons.coffee();
      case 'family friendly':
        return PhosphorIcons.users();
      case 'nature cafe':
        return PhosphorIcons.leaf();
      case 'special occasion':
        return PhosphorIcons.sparkle();
      case 'specialty coffee':
        return PhosphorIcons.coffee();
      case 'student friendly':
        return PhosphorIcons.graduationCap();
      case 'aesthetic / ig-worthy':
        return PhosphorIcons.instagramLogo();
      case 'pet friendly':
        return PhosphorIcons.dog();
      case 'free wifi':
        return PhosphorIcons.wifiHigh();
      case 'power outlets':
        return PhosphorIcons.plug();
      case 'air conditioned':
        return PhosphorIcons.snowflake();
      case 'outdoor seating':
        return PhosphorIcons.chair();
      case 'parking available':
        return PhosphorIcons.park();
      case 'reservations accepted':
        return PhosphorIcons.calendarCheck();
      case 'private rooms':
        return PhosphorIcons.doorOpen();
      case 'wheelchair accessible':
        return PhosphorIcons.wheelchair();
      case 'takeaway available':
        return PhosphorIcons.shoppingBag();
      case 'smoking area':
        return PhosphorIcons.cigarette();
      case 'open 24 hours':
        return PhosphorIcons.clock();
      default:
        if (normalized.contains('cash')) return PhosphorIcons.money();
        if (normalized.contains('card') ||
            normalized.contains('credit') ||
            normalized.contains('debit')) {
          return PhosphorIcons.creditCard();
        }
        if (normalized.contains('wallet') ||
            normalized.contains('gcash') ||
            normalized.contains('maya')) {
          return PhosphorIcons.wallet();
        }
        return null;
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
                            _iconFromTagName(tag.name) ?? Icons.circle_outlined,
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
                              icon: _iconFromTagName(tag.name),
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
                              _iconFromTagName(payment.name) ??
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

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/Frame 181(1).png',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              const Gap(16),

              Text(
                address,
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),

              const Gap(10),

              const Text(
                'Get Directions',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF3B73E6),
                  decoration: TextDecoration.underline,
                ),
              ),

              const Gap(16),

              if (socialLinks.isNotEmpty)
                Row(
                  children: [
                    if ((socialLinks['instagram']?.toString().isNotEmpty ??
                        false))
                      PhosphorIcon(
                        PhosphorIcons.instagramLogo(PhosphorIconsStyle.regular),
                        size: 28,
                        color: Color(0xFF848685),
                      ),
                    if ((socialLinks['instagram']?.toString().isNotEmpty ??
                            false) &&
                        (socialLinks['facebook']?.toString().isNotEmpty ??
                            false))
                      const Gap(18),
                    if ((socialLinks['facebook']?.toString().isNotEmpty ??
                        false))
                      PhosphorIcon(
                        PhosphorIcons.facebookLogo(PhosphorIconsStyle.regular),
                        size: 28,
                        color: Color(0xFF848685),
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
