# Claim listing link · references (ios)

Direction: project theme (`CafeDetailsTokens` in
`lib/features/cafe_details/presentation/widgets/cafe_details_common.dart`).
Researched 2026-10-11 with partwise.

## Claim listing link
Quiet footer at the bottom of cafe details inviting the owner to claim an
unclaimed listing; opens `business.nookph.app/claim/<cafeId>` in the browser.
Hidden when the cafe is claimed or the claim state hasn't loaded.
Built in `lib/features/cafe_details/presentation/widgets/cafe_claim_link.dart`.

**Primary: Airbnb.** Borrow: Google Maps. Rejected: Instagram.

| | Product | Taken |
|---|---|---|
| ![](claim-link-airbnb.png) | [Airbnb](https://refero.design/screens/7e37e27d-814f-4e89-b7b3-d0f8f6f84999) | Short helper sentence above a full-width row with leading icon, label and trailing chevron |
| ![](claim-link-googlemaps.png) | [Google Maps](https://refero.design/screens/298fd891-0dbb-4fd7-8435-f0a62808511e) | Owner-addressed question ("Is this your business?") plus a one-line benefit. Illustration not taken |
| ![](claim-link-instagram.png) | [Instagram](https://refero.design/screens/149d2815-a2c7-4b70-bff1-6ca2e64f7337) | Considered, not taken: generic link row with no owner framing |
