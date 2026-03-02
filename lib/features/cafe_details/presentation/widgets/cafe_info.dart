import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';

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

  IconData _amenityIcon(String name) {
    final text = name.toLowerCase();
    if (text.contains('wifi') || text.contains('wi-fi'))
      return LucideIcons.wifi;
    if (text.contains('air') || text.contains('ac'))
      return LucideIcons.snowflake;
    if (text.contains('plug') ||
        text.contains('outlet') ||
        text.contains('socket')) {
      return LucideIcons.plug;
    }
    if (text.contains('park')) return LucideIcons.parkingMeter;
    if (text.contains('restroom') || text.contains('toilet')) {
      return LucideIcons.toilet;
    }
    return Icons.circle_outlined;
  }

  IconData _paymentIcon(String name) {
    final text = name.toLowerCase();
    if (text.contains('cash')) return LucideIcons.banknote;
    if (text.contains('card') ||
        text.contains('credit') ||
        text.contains('debit')) {
      return LucideIcons.creditCard;
    }
    if (text.contains('wallet') ||
        text.contains('gcash') ||
        text.contains('maya')) {
      return LucideIcons.wallet;
    }
    return LucideIcons.wallet;
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
              fontSize: 18,
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
                          Icon(_amenityIcon(tag.name)),
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
                          .map((tag) => _BestForTag(label: tag.name))
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
                          icon: _paymentIcon(payment.name),
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
                      const Icon(
                        LucideIcons.instagram,
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
                      const Icon(
                        LucideIcons.facebook,
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
  const _BestForTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF868584)),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF868584),
          ),
        ),
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
