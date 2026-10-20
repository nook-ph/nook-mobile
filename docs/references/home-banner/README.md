# Home banner · references (ios, Android-first Flutter)

Direction: project theme (`lib/utils/theme/`, `docs/design_system.md`). Guessed: the
sage `primary20` card fill (the design system lists it for backgrounds; no banner token
exists). Researched 2026-10-16 with partwise.

## Home banner card
One admin-published announcement above Home's shelves: optional image, title, short
body, one CTA, close button. Contract: nook-supabase `docs/HOME_LAYOUT.md`.
Built in `lib/features/home_page/presentation/widgets/home_banner_card.dart`.

**Primary: Uber Eats.** Borrow: Substack. Considered: Matter.

| | Product | Taken |
|---|---|---|
| ![](promo-ubereats.png) | [Uber Eats](https://refero.design/screens/646604be-9aad-413a-92fe-f4492b457c43) | Banner directly above the first shelf; title, body line and a compact pill CTA stacked left, image filling the right edge |
| ![](promo-substack.png) | [Substack](https://refero.design/screens/50a85fad-d888-4014-b0fa-6f69987c8a61) | Close X as a small icon in the card's top-right corner over the image, not its own row |
| ![](promo-matter.png) | [Matter](https://refero.design/screens/6b87cbbe-7d1e-4bca-85b1-246802257b02) | Considered, not taken: eyebrow line above the title (one more text level than Home needs) |

States designed without a reference: no image (copy full width, X on the card), long
title (3 lines, ellipsis), no link (not a button, no CTA), dismissed (gone, remembered per
version), image error (sage block with a coffee glyph).
