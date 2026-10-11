import 'package:flutter/material.dart';
import 'package:nook/core/cafe/data/cafe_listing_status_source.dart';
import 'package:nook/core/presentation/widgets/confirm_sheet.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_claim_link.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/injection_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A quiet pill under the cafe's name for a listing Nook imported from public
/// sources and nobody has checked yet: "Unverified listing · Info from public
/// sources". Tapping it explains what that means and offers the owner the
/// claim page.
///
/// Renders nothing while the status loads, when the server doesn't have
/// `get_cafe_listing_status` yet, and for any cafe that is claimed, checked by
/// Nook, or wasn't imported.
class CafeUnverifiedNote extends StatefulWidget {
  const CafeUnverifiedNote({
    super.key,
    required this.cafeId,
    required this.isClaimed,
    this.statusLoader,
  });

  final String cafeId;
  final bool? isClaimed;

  /// Defaults to [CafeListingStatusSource]; tests pass their own.
  final Future<CafeListingStatus?> Function(String cafeId)? statusLoader;

  static const label = 'Unverified listing';
  static const detail = 'Info from public sources';

  @override
  State<CafeUnverifiedNote> createState() => _CafeUnverifiedNoteState();
}

class _CafeUnverifiedNoteState extends State<CafeUnverifiedNote> {
  late Future<CafeListingStatus?> _status;

  @override
  void initState() {
    super.initState();
    _status = _load();
  }

  @override
  void didUpdateWidget(CafeUnverifiedNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafeId != widget.cafeId) _status = _load();
  }

  Future<CafeListingStatus?> _load() {
    final loader = widget.statusLoader;
    if (loader != null) return loader(widget.cafeId);
    return sl<CafeListingStatusSource>().statusOf(widget.cafeId);
  }

  Future<void> _explain(BuildContext context) async {
    final claim = await showConfirmSheet(
      context,
      title: CafeUnverifiedNote.label,
      message:
          'We added this café from public sources, so its hours and details '
          'may be out of date. Nobody from the café has checked it yet.',
      confirmLabel: 'Own this café? Claim it',
      cancelLabel: 'Got it',
      destructive: false,
    );
    if (claim && context.mounted) {
      await CafeClaimLink.open(
        context,
        cafeId: widget.cafeId,
        source: 'unverified_note',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // A claimed cafe has an owner vouching for it, whatever the import says.
    if (widget.isClaimed == true) return const SizedBox.shrink();
    return FutureBuilder<CafeListingStatus?>(
      future: _status,
      builder: (context, snapshot) {
        if (snapshot.data?.isUnverified != true) {
          return const SizedBox.shrink();
        }
        final text = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: Semantics(
              button: true,
              label:
                  '${CafeUnverifiedNote.label}. ${CafeUnverifiedNote.detail}. '
                  'Opens an explanation.',
              excludeSemantics: true,
              child: AdaptiveTap(
                onTap: () => _explain(context),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: CafeDetailsTokens.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.sealQuestion(),
                        size: 16,
                        color: CafeDetailsTokens.muted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: CafeUnverifiedNote.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: CafeDetailsTokens.ink,
                                ),
                              ),
                              const TextSpan(
                                text: ' · ${CafeUnverifiedNote.detail}',
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            fontSize: 12.5,
                            color: CafeDetailsTokens.muted,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PhosphorIcon(
                        PhosphorIcons.caretRight(),
                        size: 12,
                        color: CafeDetailsTokens.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
