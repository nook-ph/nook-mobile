import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/maps_directions_launcher.dart';
import 'package:nook/features/crawls/domain/crawl_stats.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_run_cubit.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// What the user chose on the way out of the stamp sheet.
enum StampSheetResult {
  shareStop,
  recap,

  /// The crawl was removed while stamping; the run should close.
  gone,
}

/// The stamp ritual: checking → stamped, or a specific reason it didn't count.
///
/// The cubit's `stamp()` must already be running when this opens; the sheet
/// only renders its phases.
class StampSheet extends StatelessWidget {
  const StampSheet({super.key, required this.stop});

  final CrawlStop stop;

  static Future<StampSheetResult?> show(
    BuildContext context, {
    required CrawlRunCubit cubit,
    required CrawlStop stop,
  }) {
    return showModalBottomSheet<StampSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: StampSheet(stop: stop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ListsTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CrawlSheet.grabber(),
              // Figma: 8 + an 8 spacer + 8 under the grabber.
              const SizedBox(height: 24),
              BlocBuilder<CrawlRunCubit, CrawlRunState>(
                builder: (context, state) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (state.stampPhase) {
                      StampPhase.stamped => _Stamped(
                        key: const ValueKey('stamped'),
                        stop: stop,
                        stopCount: state.run?.crawl.stops.length ?? 0,
                        complete: state.run?.isComplete ?? false,
                      ),
                      StampPhase.failed => _Failed(
                        key: const ValueKey('failed'),
                        stop: stop,
                        error: state.stampError,
                      ),
                      _ => _Checking(
                        key: const ValueKey('checking'),
                        stop: stop,
                        stopCount: state.run?.crawl.stops.length ?? 0,
                      ),
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seal (or icon) to title: 8 + a 6 spacer + 8.
const _toTitle = SizedBox(height: 22);

/// The sheet's own gap between neighbours.
const _gap = SizedBox(height: 8);

/// Text to the first button: 8 + a 10 spacer + 8.
const _toActions = SizedBox(height: 26);

/// The seal on the stamp sheet (Figma: 104).
const _sealSize = 104.0;

class _Checking extends StatelessWidget {
  const _Checking({super.key, required this.stop, required this.stopCount});

  final CrawlStop stop;
  final int stopCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The seal is faint until the server says yes.
        Opacity(
          opacity: 0.35,
          child: CrawlSeal(size: _sealSize, label: '${stop.order}', ring: true),
        ),
        _toTitle,
        Text(
          'Checking you’re here…',
          textAlign: TextAlign.center,
          style: crawlText(20, weight: FontWeight.w600),
        ),
        _gap,
        Text(
          '${stop.name} · Stop ${stop.order} of $stopCount',
          textAlign: TextAlign.center,
          style: crawlText(14, color: ListsTokens.muted),
        ),
        // Figma: 8 + a 24 spacer.
        const SizedBox(height: 32),
      ],
    );
  }
}

class _Stamped extends StatelessWidget {
  const _Stamped({
    super.key,
    required this.stop,
    required this.stopCount,
    required this.complete,
  });

  final CrawlStop stop;
  final int stopCount;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: MediaQuery.disableAnimationsOf(context)
              ? Curves.linear
              : Curves.elasticOut,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: CrawlSeal(size: _sealSize, label: '${stop.order}', ring: true),
        ),
        _toTitle,
        Text(
          'Stamped!',
          textAlign: TextAlign.center,
          style: crawlText(24, weight: FontWeight.w600),
        ),
        _gap,
        Text(
          '${stop.name} · Stop ${stop.order} of $stopCount',
          textAlign: TextAlign.center,
          style: crawlText(14, color: ListsTokens.muted),
        ),
        _gap,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.check, size: 14, color: ListsTokens.brand),
            const SizedBox(width: 6),
            Text(
              'Added to your Been list',
              style: crawlText(
                12,
                weight: FontWeight.w500,
                color: ListsTokens.brand,
              ),
            ),
          ],
        ),
        _toActions,
        CrawlPrimaryButton(
          label: complete ? 'See your recap' : 'Keep going',
          onTap: () => Navigator.of(
            context,
          ).pop(complete ? StampSheetResult.recap : null),
        ),
        _gap,
        CrawlPrimaryButton(
          label: 'Share this stop',
          outlined: true,
          onTap: () => Navigator.of(context).pop(StampSheetResult.shareStop),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.stop, required this.error});

  final CrawlStop stop;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(error, stop);
    final cubit = context.read<CrawlRunCubit>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: crawlTint,
            shape: BoxShape.circle,
          ),
          child: Icon(copy.icon, size: 28, color: ListsTokens.brand),
        ),
        _toTitle,
        Text(
          copy.title,
          textAlign: TextAlign.center,
          style: crawlText(20, weight: FontWeight.w600),
        ),
        _gap,
        Text(
          copy.body,
          textAlign: TextAlign.center,
          style: crawlText(14, color: ListsTokens.muted),
        ),
        _toActions,
        switch (copy.action) {
          _FailAction.retry => CrawlPrimaryButton(
            label: 'Try again',
            onTap: () => cubit.stamp(stop),
          ),
          _FailAction.locationSettings => CrawlPrimaryButton(
            label: 'Open location settings',
            onTap: Geolocator.openLocationSettings,
          ),
          _FailAction.appSettings => CrawlPrimaryButton(
            label: 'Open settings',
            onTap: Geolocator.openAppSettings,
          ),
          _FailAction.close => CrawlPrimaryButton(
            label: 'OK',
            // A removed crawl has no run page to go back to: the caller
            // returns to Lists instead of only closing the sheet.
            onTap: () => Navigator.of(
              context,
            ).pop(error is CrawlNotFound ? StampSheetResult.gone : null),
          ),
        },
        if (error is StampTooFar) ...[
          _gap,
          CrawlTextButton(
            label: 'Get directions',
            color: ListsTokens.muted,
            minHeight: 40,
            onTap: () => MapsDirectionsLauncher.launchDirections(
              lat: stop.lat,
              lng: stop.lng,
              label: stop.name,
              platform: Theme.of(context).platform,
            ),
          ),
        ],
      ],
    );
  }

  static _FailCopy _copyFor(Object? error, CrawlStop stop) {
    return switch (error) {
      StampTooFar(:final distanceMeters) => _FailCopy(
        icon: LucideIcons.mapPin,
        title:
            'You’re about '
            '${CrawlStats.formatDistance(distanceMeters.toDouble())} away',
        body:
            'Get closer to ${stop.name} and try again. '
            'Stamps only count at the cafe.',
      ),
      StampTooSoon(:final waitSeconds) => _FailCopy(
        icon: LucideIcons.hourglass,
        title: 'Give it a few minutes',
        body:
            'You stamped another stop moments ago. Try again in '
            '${_minutes(waitSeconds)}.',
        action: _FailAction.close,
      ),
      StampLowAccuracy() => _FailCopy(
        icon: LucideIcons.locateOff,
        title: 'We can’t pin down where you are',
        body: 'Step outside or near a window, then try again.',
      ),
      StampLocationUnavailable(:final problem) => switch (problem) {
        LocationProblem.serviceOff => _FailCopy(
          icon: LucideIcons.locateOff,
          title: 'Location is turned off',
          body: 'Turn on location to stamp this stop.',
          action: _FailAction.locationSettings,
        ),
        LocationProblem.deniedForever => _FailCopy(
          icon: LucideIcons.locateOff,
          title: 'Nook needs your location',
          body:
              'Stamps are checked against where you are. Allow location '
              'for Nook in Settings.',
          action: _FailAction.appSettings,
        ),
        LocationProblem.denied => _FailCopy(
          icon: LucideIcons.locateOff,
          title: 'Nook needs your location',
          body:
              'Stamps are checked against where you are. It is only used '
              'at the moment you stamp.',
        ),
        LocationProblem.timeout => _FailCopy(
          icon: LucideIcons.locateOff,
          title: 'Couldn’t get your location',
          body: 'Check your signal, then try again.',
        ),
      },
      CrawlNotFound() => _FailCopy(
        icon: LucideIcons.x,
        title: 'This crawl is no longer available',
        body: 'It may have been removed.',
        action: _FailAction.close,
      ),
      _ => () {
        final info = AppErrorCopy.fromException(error ?? Exception());
        return _FailCopy(
          icon: LucideIcons.triangleAlert,
          title: info.title,
          body: info.subtitle,
        );
      }(),
    };
  }

  static String _minutes(int seconds) {
    final minutes = (seconds / 60).ceil().clamp(1, 60);
    return minutes == 1 ? 'a minute' : '$minutes minutes';
  }
}

enum _FailAction { retry, locationSettings, appSettings, close }

class _FailCopy {
  const _FailCopy({
    required this.icon,
    required this.title,
    required this.body,
    this.action = _FailAction.retry,
  });

  final IconData icon;
  final String title;
  final String body;
  final _FailAction action;
}
