/// Failures the crawl UI has specific copy for. Anything else surfaces through
/// `AppErrorCopy` like the rest of the app.
sealed class CrawlException implements Exception {
  const CrawlException();
}

/// The crawl or run is gone, private, or the caller is not part of it. The
/// server deliberately does not say which.
class CrawlNotFound extends CrawlException {
  const CrawlNotFound();
}

class CrewFull extends CrawlException {
  const CrewFull();
}

/// The server rejected the crawl's shape (title length, stop count, an
/// unknown cafe). [code] is the server's token, for logging.
class CrawlInvalid extends CrawlException {
  final String code;
  const CrawlInvalid(this.code);
}

class CrawlRateLimited extends CrawlException {
  const CrawlRateLimited();
}

/// Too far from the cafe. [distanceMeters] is what the server measured.
class StampTooFar extends CrawlException {
  final int distanceMeters;
  const StampTooFar(this.distanceMeters);
}

/// Stamped another stop too recently.
class StampTooSoon extends CrawlException {
  final int waitSeconds;
  const StampTooSoon(this.waitSeconds);
}

/// The device's fix was too imprecise to trust.
class StampLowAccuracy extends CrawlException {
  final int accuracyMeters;
  const StampLowAccuracy(this.accuracyMeters);
}

enum LocationProblem { serviceOff, denied, deniedForever, timeout }

/// No usable position: a stamp cannot be attempted at all.
class StampLocationUnavailable extends CrawlException {
  final LocationProblem problem;
  const StampLocationUnavailable(this.problem);
}
