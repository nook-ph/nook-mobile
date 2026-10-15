import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/location/cebu_coverage.dart';
import 'package:nook/core/utils/geo.dart';

const _itPark = GeoPoint(lat: 10.3302, lng: 123.9067);
const _danao = GeoPoint(lat: 10.5206, lng: 124.0275);
const _manila = GeoPoint(lat: 14.5995, lng: 120.9842);

void main() {
  test('Metro Cebu and its edge towns are inside', () {
    expect(CebuCoverage.contains(_itPark), isTrue);
    expect(CebuCoverage.contains(_danao), isTrue);
    expect(CebuCoverage.contains(_manila), isFalse);
  });

  test('the device decides when there is one', () {
    expect(CebuCoverage.isOutside(device: _manila), isTrue);
    expect(CebuCoverage.isOutside(device: _itPark), isFalse);
    expect(CebuCoverage.isOutside(device: _itPark, viewing: _manila), isFalse);
  });

  test('someone outside Cebu who is viewing Cebu is not outside', () {
    expect(CebuCoverage.isOutside(device: _manila, viewing: _itPark), isFalse);
    expect(CebuCoverage.isOutside(device: _manila, viewing: _manila), isTrue);
  });

  test('without a device the viewed place decides; with neither, no', () {
    expect(CebuCoverage.isOutside(viewing: _manila), isTrue);
    expect(CebuCoverage.isOutside(viewing: _itPark), isFalse);
    expect(CebuCoverage.isOutside(), isFalse);
  });
}
