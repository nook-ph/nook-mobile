import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

IconData? resolveTagIcon(String? tagName) {
  if (tagName == null || tagName.trim().isEmpty) {
    return null;
  }

  final name = tagName.trim().toLowerCase();

  switch (name) {
    case 'date spot':
      return PhosphorIcons.heart();
    case 'solo work / study':
      return PhosphorIcons.laptop();
    case 'community space':
      return PhosphorIcons.usersThree();
    case 'group hangout':
    case 'family friendly':
      return PhosphorIcons.users();
    case 'book cafe':
      return PhosphorIcons.bookOpen();
    case 'late night':
      return PhosphorIcons.moon();
    case 'quick coffee':
    case 'specialty coffee':
      return PhosphorIcons.coffee();
    case 'nature cafe':
      return PhosphorIcons.leaf();
    case 'special occasion':
      return PhosphorIcons.sparkle();
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
      return PhosphorIcons.letterCircleP();
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
      if (name.contains('wifi')) return PhosphorIcons.wifiHigh();
      if (name.contains('cash')) return PhosphorIcons.money();
      if (name.contains('card') ||
          name.contains('credit') ||
          name.contains('debit')) {
        return PhosphorIcons.creditCard();
      }
      if (name.contains('wallet') ||
          name.contains('gcash') ||
          name.contains('maya')) {
        return PhosphorIcons.wallet();
      }
      return null;
  }
}
