import 'package:flutter/material.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_by_code_usecase.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_detail_page.dart';
import 'package:nook/features/crawls/presentation/pages/crew_invite_page.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/injection_container.dart';

/// What a typed or pasted code points at.
///
/// Both codes are uppercase hex cut from a UUID server-side
/// (`_community_crawl_code`): 8 characters for a crawl's share code, 10 for a
/// run's crew invite.
class CrawlCodeTarget {
  const CrawlCodeTarget.crawl(this.code) : isInvite = false;
  const CrawlCodeTarget.invite(this.code) : isInvite = true;

  final String code;

  /// True for a crew invite, false for a crawl share code.
  final bool isInvite;

  static const shareCodeLength = 8;
  static const inviteCodeLength = 10;

  static final _hex = RegExp(r'^[0-9A-F]+$');

  static bool _isCode(String value, int length) =>
      value.length == length && _hex.hasMatch(value);

  /// Reads a bare code or a pasted `nookph.app/c/<code>` link. A link with
  /// `?crew=<invite>` is an invite. Null when nothing usable is in [input].
  static CrawlCodeTarget? parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    if (raw.contains('/') || raw.contains('?')) {
      final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
      if (uri == null) return null;
      final crew = (uri.queryParameters['crew'] ?? '').trim().toUpperCase();
      if (_isCode(crew, inviteCodeLength)) return CrawlCodeTarget.invite(crew);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;
      final last = segments.last.trim().toUpperCase();
      return _isCode(last, shareCodeLength)
          ? CrawlCodeTarget.crawl(last)
          : null;
    }

    final code = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (_isCode(code, shareCodeLength)) return CrawlCodeTarget.crawl(code);
    if (_isCode(code, inviteCodeLength)) return CrawlCodeTarget.invite(code);
    return null;
  }
}

/// "Enter a code" on the Lists tab: opens a crawl from its share code, or a
/// crew invite from its invite code.
class EnterCrawlCodeSheet extends StatefulWidget {
  const EnterCrawlCodeSheet({super.key});

  /// Opens the sheet, then the page the code leads to.
  static Future<void> show(BuildContext context) async {
    final navigator = Navigator.of(context);
    final result = await CrawlSheet.show<Object>(
      context,
      builder: (_) => const EnterCrawlCodeSheet(),
    );
    if (result is Crawl) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              CrawlDetailPage(shareCode: result.shareCode, initial: result),
        ),
      );
    } else if (result is CrawlCodeTarget && result.isInvite) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CrewInvitePage(inviteCode: result.code),
        ),
      );
    }
  }

  @override
  State<EnterCrawlCodeSheet> createState() => _EnterCrawlCodeSheetState();
}

class _EnterCrawlCodeSheetState extends State<EnterCrawlCodeSheet> {
  static const _notFound = 'No crawl with that code';

  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_checking) return;
    final target = CrawlCodeTarget.parse(_controller.text);
    if (target == null) {
      setState(() => _error = _notFound);
      return;
    }
    if (target.isInvite) {
      // The invite page loads its own preview and has its own states.
      Navigator.of(context).pop(target);
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final crawl = await sl<GetCrawlByCodeUseCase>()(target.code);
      if (!mounted) return;
      Navigator.of(context).pop(crawl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = e is CrawlNotFound
            ? _notFound
            : AppErrorCopy.fromException(e).subtitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrawlSheet(
      title: 'Enter a crawl code',
      gap: 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'It is the ${CrawlCodeTarget.shareCodeLength} characters after '
            'nookph.app/c/',
            style: crawlText(12, color: ListsTokens.muted),
          ),
          const SizedBox(height: 14),
          CrawlTextField(
            controller: _controller,
            hint: 'K7M2QX9A',
            // Figma: 16 SemiBold in a field with a 1pt brand border.
            textStyle: crawlText(16, weight: FontWeight.w600),
            emphasisWidth: 1,
            errorText: _error,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _open(),
          ),
          const SizedBox(height: 14),
          CrawlPrimaryButton(
            label: 'Open crawl',
            busy: _checking,
            onTap: _controller.text.trim().isEmpty ? null : _open,
          ),
        ],
      ),
    );
  }
}
