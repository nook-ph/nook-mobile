import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';
import 'package:nook/injection_container.dart';

/// "People" in search, for a query typed as "@" plus the start of a
/// username: up to five matching people, each opening their profile. Only
/// usernames are searched, so nobody is found by a name they did not choose
/// to be found by.
class PeopleMatches extends StatefulWidget {
  const PeopleMatches({
    super.key,
    required this.prefix,
    this.repository,
    this.onOpen,
    this.quiet = false,
    this.limit = 5,
  });

  /// Under cafe matches for a plain query: shows only when someone
  /// matches, with no "Looking…", error or "No one" line.
  final bool quiet;

  final int limit;

  /// The username start, without "@".
  final String prefix;

  /// Defaults to the app's.
  final IPublicProfileRepository? repository;

  /// Called before a profile opens (search saves the query as a recent).
  final VoidCallback? onOpen;

  @override
  State<PeopleMatches> createState() => _PeopleMatchesState();
}

class _PeopleMatchesState extends State<PeopleMatches> {
  static const _debounce = Duration(milliseconds: 250);

  Timer? _timer;
  List<PersonMatch>? _people;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(PeopleMatches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prefix != widget.prefix) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_debounce, _search);
  }

  Future<void> _search() async {
    final generation = ++_generation;
    final repo = widget.repository ?? sl<IPublicProfileRepository>();
    try {
      final people = await repo.searchPeople(
        widget.prefix,
        limit: widget.limit,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _people = people;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    if (widget.quiet && (people == null || people.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Semantics(
            header: true,
            child: Text(
              'People',
              style: ProfileTokens.text(
                12,
                weight: FontWeight.w500,
                color: ProfileTokens.muted,
              ),
            ),
          ),
        ),
        if (_failed)
          _Line('Could not search people. Check your connection.')
        else if (people == null)
          const _Line('Looking…')
        else if (people.isEmpty)
          _Line('No one goes by @${widget.prefix}')
        else
          for (final person in people)
            _PersonRow(
              person: person,
              onTap: () {
                widget.onOpen?.call();
                PublicProfilePage.open(
                  context,
                  username: person.username,
                  nameHint: person.fullName,
                  source: ProfileViewSource.search,
                );
              },
            ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: ProfileTokens.text(14, color: ProfileTokens.muted),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onTap});

  final PersonMatch person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = person.fullName?.trim() ?? '';
    return Semantics(
      button: true,
      label: [
        '@${person.username}',
        if (name.isNotEmpty) name,
        'profile',
      ].join(', '),
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              ProfileAvatar(
                name: name.isEmpty ? person.username : name,
                imageUrl: person.avatarUrl,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${person.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileTokens.text(14, weight: FontWeight.w500),
                    ),
                    if (name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileTokens.text(
                          12,
                          color: ProfileTokens.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
