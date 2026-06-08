import 'package:nook/core/errors/failure.dart';

class LocationTooFarFailure extends Failure {
  final int distanceMeters;

  LocationTooFarFailure(this.distanceMeters) : super('Location too far');
}

class AlreadyClaimedFailure extends Failure {
  final DateTime claimedAt;

  AlreadyClaimedFailure(this.claimedAt) : super('Already claimed');
}

class CrawlEndedFailure extends Failure {
  CrawlEndedFailure() : super('Crawl has ended');
}

class StopInactiveFailure extends Failure {
  StopInactiveFailure() : super('Stop is inactive');
}

class AlreadyRegisteredFailure extends Failure {
  AlreadyRegisteredFailure() : super('Already registered');
}

class CrawlNotFoundFailure extends Failure {
  CrawlNotFoundFailure() : super('Crawl not found');
}
