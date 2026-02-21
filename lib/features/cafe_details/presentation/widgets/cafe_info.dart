import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:gap/gap.dart';

class CafeInfo extends StatelessWidget {
  const CafeInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),

          Gap(16),

          //amenities
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AMENITIES',
                style: TextStyle(fontSize: 15, color: Color(0xFF848685)),
              ),

              Gap(12),

              Column(
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.wifi),

                      Gap(18),

                      Text(
                        'Free High-Speed Wifi',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF848685),
                        ),
                      ),
                    ],
                  ),

                  Gap(18),

                  Row(
                    children: [
                      Icon(LucideIcons.snowflake),

                      Gap(18),

                      Text(
                        'Air Conditioned',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF848685),
                        ),
                      ),
                    ],
                  ),

                  Gap(18),

                  Row(
                    children: [
                      Icon(LucideIcons.plug),

                      Gap(18),

                      Text(
                        'Power Outlets',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF848685),
                        ),
                      ),
                    ],
                  ),

                  Gap(18),

                  Row(
                    children: [
                      Icon(LucideIcons.parkingMeter),

                      Gap(18),

                      Text(
                        'Parking',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF848685),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          Gap(28),

          Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          Gap(28),

          //best for
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BEST FOR',
                style: TextStyle(fontSize: 15, color: Color(0xFF848685)),
              ),

              Gap(12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _BestForTag(label: 'Work'),
                  _BestForTag(label: 'Study'),
                  _BestForTag(label: 'Meetings'),
                  _BestForTag(label: 'Groups'),
                  _BestForTag(label: 'Solo Time'),
                  _BestForTag(label: 'Solo Time'),
                ],
              ),
            ],
          ),

          Gap(28),

          Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          Gap(28),

          //accepted payments
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCEPTED PAYMENTS',
                style: TextStyle(fontSize: 15, color: Color(0xFF848685)),
              ),

              Gap(18),

              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: const [
                  _PaymentType(icon: LucideIcons.banknote, label: 'Cash'),

                  Gap(16),
                  _PaymentType(icon: LucideIcons.wallet, label: 'E-Wallet'),

                  Gap(16),
                  _PaymentType(icon: LucideIcons.creditCard, label: 'Card'),
                ],
              ),
            ],
          ),

          Gap(28),

          Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          Gap(28),

          //location & contacts
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOCATION & CONTACTS',
                style: TextStyle(fontSize: 15, color: Color(0xFF848685)),
              ),

              Gap(16),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/Frame 181(1).png',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              Gap(16),

              Text(
                'Ground Floor, Summit Galleria Cebu, Cebu City Philippines',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),

              Gap(10),

              Text(
                'Get Directions',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF3B73E6),
                  decoration: TextDecoration.underline,
                ),
              ),

              Gap(16),

              Row(
                children: [
                  Icon(
                    LucideIcons.instagram,
                    size: 28,
                    color: Color(0xFF848685),
                  ),
                  Gap(18),
                  Icon(
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
