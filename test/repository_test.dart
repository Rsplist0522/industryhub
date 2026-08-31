import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:industryhub/core/app_state.dart';
import 'package:industryhub/features/fair_price/data/market_price_repository.dart';
import 'package:industryhub/features/resource_marketplace/data/industrial_context_repository.dart';
import 'package:industryhub/features/skill_match/data/training_programme_repository.dart';

void main() {
  group('Profile readiness rules', () {
    test('requires business name and sector before unlocking matching features', () {
      expect(const CompanyProfile().hasRequiredProfileIdentity, isFalse);
      expect(
        const CompanyProfile(businessName: 'Sunrise Foundry').hasRequiredProfileIdentity,
        isFalse,
      );
      expect(
        const CompanyProfile(
          businessName: 'Sunrise Foundry',
          sector: 'Machinery and equipment',
        ).hasRequiredProfileIdentity,
        isTrue,
      );
    });
  });

  group('Supabase row mappers', () {
    test('maps listing numeric and nullable fields safely', () {
      final listing = Listing.fromSupabase({
        'id': 'listing-1',
        'type': 'supply',
        'material': 'Aluminium',
        'quantity': '125.5',
        'unit': 'kg',
        'location': 'Penang',
        'description': 'Sorted',
        'owner': 'Example SME',
        'owner_id': 'user-1',
        'verified': true,
        'asking_price_per_kg': 4.25,
      });

      expect(listing.id, 'listing-1');
      expect(listing.quantity, 125.5);
      expect(listing.askingPricePerKg, 4.25);
      expect(listing.verified, isTrue);
    });

    test('maps training programme skills and duration', () {
      final programme = TrainingProgramme.fromSupabase({
        'id': 'course-1',
        'name': 'Industrial Analytics',
        'provider': 'Example Provider',
        'skills': ['Data and analytics'],
        'level': 'Intermediate',
        'duration_days': 4,
        'source_name': 'Live catalogue',
        'source_url': 'https://example.com/course-1',
      });

      expect(programme.skills, ['Data and analytics']);
      expect(programme.durationDays, 4);
      expect(programme.sourceUrl, 'https://example.com/course-1');
    });
  });

  test('parses the newest official data.gov.my PPI record', () {
    final result = parseDataGovPpiResponse(
      jsonEncode([
        {'date': '2024-01-01', 'index': 100.0, 'series': 'abs'},
        {'date': '2024-03-01', 'index': 102.5, 'series': 'abs'},
        {'date': '2024-03-01', 'index': 999.0, 'series': 'other'},
      ]),
    );

    expect(result?.indexValue, 102.5);
    expect(result?.sourceUrl, 'https://data.gov.my/data-catalogue/ppi');
    expect(result?.sourceName, contains('data.gov.my'));
  });

  test(
    'normalizes a supported state and parses the newest official record',
    () async {
      final client = _FakeHttpClient(
        (request) async => http.Response(
          jsonEncode([
            {'date': '2024-01-01', 'state': 'Pulau Pinang', 'value': 51000.0},
          ]),
          200,
        ),
      );
      final repository = IndustrialContextRepository(client: client);

      final result = await repository.fetchManufacturingContext(
        marketplaceLocation: 'Bayan Lepas, Penang',
      );

      expect(result?.state, 'Pulau Pinang');
      expect(result?.valueRmMillions, 51000.0);
      expect(
        client.lastRequest?.queryParameters['ifilter'],
        'Pulau Pinang@state',
      );
    },
  );

  test('returns null without requesting unsupported locations', () async {
    final client = _FakeHttpClient((request) async => http.Response('[]', 200));
    final repository = IndustrialContextRepository(client: client);

    final result = await repository.fetchManufacturingContext(
      marketplaceLocation: 'International Zone',
    );

    expect(result, isNull);
    expect(client.lastRequest, isNull);
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;
  Uri? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request.url;
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
