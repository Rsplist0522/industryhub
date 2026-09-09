import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

const _courseraSearchUrl = 'https://www.coursera.org/search';
const _msicApiUrl =
    'https://api.data.gov.my/data-catalogue?id=msic&limit=10000';
const _workforceSkillsApiUrl =
    'https://api.data.gov.my/data-catalogue?id=lfs_qtr_sru_age&limit=10000';
const _ppiCsvUrl = 'https://storage.dosm.gov.my/ppi/ppi.csv';
const _fredSeries = <String, String>{
  'WPU102402': 'Secondary Aluminum',
  'WPU102301': 'Copper Base Scrap',
  'WPU1012': 'Iron and Steel Scrap',
};

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (!dryRun &&
      (supabaseUrl == null ||
          supabaseUrl.isEmpty ||
          serviceRoleKey == null ||
          serviceRoleKey.isEmpty)) {
    stderr.writeln(
      'Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running this importer.',
    );
    exitCode = 64;
    return;
  }

  final courseQuery = _argumentValue(args, '--course-query');
  final api = dryRun || supabaseUrl == null || serviceRoleKey == null
      ? null
      : _SupabaseRestClient(Uri.parse(supabaseUrl), serviceRoleKey);
  final client = http.Client();
  try {
    await _upsertSources(api);
    var courseCount = 0;
    var msicCount = 0;
    var workforceSkillCount = 0;
    var ppiCount = 0;
    var metalCount = 0;
    try {
      final specifications = courseQuery == null
          ? await _loadSkillMatchCourseSpecifications()
          : [_CourseImportSpecification(query: courseQuery)];
      courseCount = await _importCoursera(client, api, specifications);
    } catch (error) {
      stderr.writeln('Coursera source skipped: $error');
    }
    try {
      msicCount = await _importMsic(client, api);
    } catch (error) {
      stderr.writeln('DOSM MSIC source skipped: $error');
    }
    try {
      workforceSkillCount = await _importWorkforceSkills(client, api);
    } catch (error) {
      stderr.writeln('DOSM workforce-skills source skipped: $error');
    }
    try {
      ppiCount = await _importPpi(client, api);
    } catch (error) {
      stderr.writeln('DOSM PPI source skipped: $error');
    }
    try {
      metalCount = await _importFredMetalIndexes(client, api);
    } catch (error) {
      stderr.writeln('FRED metal sources skipped: $error');
    }
    stdout.writeln(
      '${dryRun ? 'Live-source dry run' : 'Live ingestion'} complete: $courseCount courses, $msicCount MSIC rows, $workforceSkillCount workforce-signal rows, $ppiCount PPI rows, $metalCount metal observations.',
    );
  } finally {
    client.close();
  }
}

String? _argumentValue(List<String> args, String name) {
  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg.startsWith('$name=')) return arg.substring(name.length + 1);
    if (arg == name && index + 1 < args.length) return args[index + 1];
  }
  return null;
}

Future<void> _upsertSources(_SupabaseRestClient? api) async {
  if (api == null) return;
  await api.upsert('data_sources', [
    {
      'id': 'skillmatch-coursera-live',
      'module_key': 'skill_match',
      'name': 'Coursera public course catalogue',
      'access_type': 'Dart HTML crawl',
      'source_url': _courseraSearchUrl,
      'requires_api_key': false,
      'license': null,
      'notes':
          'Course records are imported from the public search page with outbound course URLs.',
    },
    {
      'id': 'skillmatch-dosm-workforce-signal',
      'module_key': 'skill_match',
      'name': 'Quarterly Skills-Related Underemployment by Age',
      'access_type': 'Public Open API',
      'source_url': 'https://data.gov.my/data-catalogue/lfs_qtr_sru_age',
      'requires_api_key': false,
      'license': 'CC BY 4.0',
      'notes':
          'DOSM labour-force skills signal used as Malaysian workforce context for SkillMatch recommendations.',
    },
    {
      'id': 'resource-profile-msic-live',
      'module_key': 'resource_profile',
      'name': 'Malaysia Standard Industrial Classification',
      'access_type': 'Public Open API',
      'source_url': 'https://data.gov.my/data-catalogue/msic',
      'requires_api_key': false,
      'license': 'CC BY 4.0',
      'notes':
          'Official DOSM classification rows imported through the public API.',
    },
    {
      'id': 'fairprice-malaysia-ppi-live',
      'module_key': 'fair_price',
      'name': 'Malaysia Producer Price Index',
      'access_type': 'Public CSV',
      'source_url': 'https://data.gov.my/data-catalogue/ppi',
      'requires_api_key': false,
      'license': 'CC BY 4.0',
      'notes':
          'Historical monthly PPI rows imported from the DOSM public CSV endpoint.',
    },
  ], onConflict: 'id');
}

Future<List<_CourseImportSpecification>>
_loadSkillMatchCourseSpecifications() async {
  final decoded = jsonDecode(
    await File('assets/data/skillmatch_role_profiles.json').readAsString(),
  );
  if (decoded is! Map || decoded['profiles'] is! List) {
    throw const FormatException('SkillMatch role profile asset is invalid.');
  }
  return (decoded['profiles'] as List)
      .whereType<Map>()
      .map((raw) {
        final profile = Map<String, dynamic>.from(raw);
        final competencies =
            (profile['competencies'] as List? ?? const [])
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList()
              ..sort(
                (a, b) => ((b['weight'] as num?) ?? 0).compareTo(
                  (a['weight'] as num?) ?? 0,
                ),
              );
        final skills = competencies
            .take(3)
            .map((skill) => '${skill['name'] ?? ''}'.trim())
            .where((skill) => skill.isNotEmpty)
            .toList();
        final title = '${profile['title'] ?? ''}'.trim();
        return _CourseImportSpecification(
          query: [title, ...skills].join(' '),
          roleId: '${profile['id'] ?? ''}'.trim(),
          roleTitle: title,
          industry: '${profile['industry'] ?? ''}'.trim(),
          skills: skills,
        );
      })
      .where((specification) => specification.query.isNotEmpty)
      .toList();
}

Future<int> _importCoursera(
  http.Client client,
  _SupabaseRestClient? api,
  Iterable<_CourseImportSpecification> specifications,
) async {
  var imported = 0;
  for (final specification in specifications) {
    imported += await _importCourseraQuery(client, api, specification);
  }
  return imported;
}

Future<int> _importCourseraQuery(
  http.Client client,
  _SupabaseRestClient? api,
  _CourseImportSpecification specification,
) async {
  final query = specification.query;
  final uri = Uri.parse(
    '$_courseraSearchUrl?query=${Uri.encodeQueryComponent(query)}',
  );
  final response = await client
      .get(uri, headers: {'User-Agent': 'IndustryHub-LiveDataImporter/1.0'})
      .timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw StateError('Coursera returned HTTP ${response.statusCode}.');
  }

  final document = html_parser.parse(response.body);
  final seen = <String>{};
  final rows = <Map<String, dynamic>>[];
  for (final anchor in document.querySelectorAll('a[href]')) {
    final href = anchor.attributes['href'] ?? '';
    if (!href.startsWith('/learn/') &&
        !href.startsWith('/specializations/') &&
        !href.startsWith('/professional-certificates/')) {
      continue;
    }
    final courseUrl = Uri.parse(
      'https://www.coursera.org$href',
    ).removeFragment().toString();
    if (!seen.add(courseUrl)) continue;
    final title = _cleanText(anchor.text);
    if (title.length < 5 || title.toLowerCase().contains('coursera plus')) {
      continue;
    }
    rows.add({
      'id':
          'coursera-${base64Url.encode(utf8.encode(courseUrl)).replaceAll('=', '')}',
      'name': title,
      'provider': _providerFromCard(anchor) ?? 'Coursera provider',
      'skills': specification.skills.isEmpty
          ? _skillsForQuery(query)
          : specification.skills,
      'level': 'Not specified',
      'duration_days': 0,
      'source_name': 'Coursera public course catalogue',
      'source_url': courseUrl,
      'credential': href.startsWith('/professional-certificates/')
          ? 'Professional Certificate page'
          : 'Course or certificate details',
      'summary':
          'Live course listing imported for “$query”. Open the source page for current syllabus, pricing, and certificate terms.',
      'industry': specification.industry,
      'target_roles': [
        if (specification.roleId.isNotEmpty) specification.roleId,
        if (specification.roleTitle.isNotEmpty) specification.roleTitle,
      ],
      'metadata_note': specification.roleId.isEmpty
          ? 'Skill tags were derived from the requested provider search topic. Verify the syllabus at the source page.'
          : 'Role and skill tags were derived from the bundled SkillMatch search specification. Verify the syllabus at the source page.',
      'is_active': true,
    });
    if (rows.length == 30) break;
  }
  if (rows.isNotEmpty && api != null) {
    await api.upsert('training_programmes', rows, onConflict: 'id');
  }
  return rows.length;
}

class _CourseImportSpecification {
  const _CourseImportSpecification({
    required this.query,
    this.roleId = '',
    this.roleTitle = '',
    this.industry = '',
    this.skills = const [],
  });

  final String query;
  final String roleId;
  final String roleTitle;
  final String industry;
  final List<String> skills;
}

String? _providerFromCard(dynamic anchor) {
  final parent = anchor.parent;
  if (parent == null) return null;
  final text = _cleanText(parent.text);
  final title = _cleanText(anchor.text);
  if (text == title || text.isEmpty) return null;
  final remainder = text.replaceFirst(title, '').trim();
  return remainder.length > 80 ? null : remainder;
}

List<String> _skillsForQuery(String query) {
  final value = query.trim().toLowerCase();
  final skills = <String>[query.trim()];
  if (value.contains('software') ||
      value.contains('developer') ||
      value.contains('program')) {
    skills.add('Software engineering');
  }
  if (value.contains('data') || value.contains('analytics')) {
    skills.add('Data and analytics');
  }
  if (value.contains('cloud') || value.contains('devops')) {
    skills.add('Cloud and DevOps');
  }
  if (value.contains('web') || value.contains('full stack')) {
    skills.add('Web development');
  }
  return skills.toSet().toList();
}

Future<int> _importMsic(http.Client client, _SupabaseRestClient? api) async {
  final response = await client
      .get(
        Uri.parse(_msicApiUrl),
        headers: {'User-Agent': 'IndustryHub-LiveDataImporter/1.0'},
      )
      .timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw StateError('DOSM MSIC returned HTTP ${response.statusCode}.');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! List) {
    throw const FormatException('DOSM MSIC response was not a list.');
  }
  final rows = decoded
      .whereType<Map>()
      .map((raw) {
        final data = Map<String, dynamic>.from(raw);
        final section = '${data['section'] ?? ''}'.trim();
        final division = '${data['division'] ?? ''}'.trim();
        final group = '${data['group'] ?? ''}'.trim();
        final classCode = '${data['class'] ?? ''}'.trim();
        final item = '${data['item'] ?? ''}'.trim();
        final codeParts = [
          section,
          division,
          group,
          classCode,
          item,
        ].where((part) => part.isNotEmpty && part != '-');
        return {
          'item_code': codeParts.join('-'),
          'digits': (data['digits'] as num?)?.toInt() ?? 0,
          'section': section,
          'division': division,
          'group_code': group,
          'class_code': classCode,
          'description_en': '${data['desc_en'] ?? ''}'.trim(),
          'description_bm': '${data['desc_bm'] ?? ''}'.trim(),
          'source_name': 'Department of Statistics Malaysia',
          'source_url': 'https://data.gov.my/data-catalogue/msic',
        };
      })
      .where(
        (row) =>
            (row['item_code'] as String).isNotEmpty &&
            (row['description_en'] as String).isNotEmpty,
      )
      .toList();
  if (api != null) {
    for (final chunk in _chunks(rows, 500)) {
      await api.upsert('msic_codes', chunk, onConflict: 'item_code');
    }
  }
  return rows.length;
}

Future<int> _importFredMetalIndexes(
  http.Client client,
  _SupabaseRestClient? api,
) async {
  var count = 0;
  for (final entry in _fredSeries.entries) {
    final url =
        'https://fred.stlouisfed.org/graph/fredgraph.csv?id=${entry.key}&cosd=2020-01-01';
    late final http.Response response;
    try {
      response = await client
          .get(
            Uri.parse(url),
            headers: {'User-Agent': 'IndustryHub-LiveDataImporter/1.0'},
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      stderr.writeln(
        'FRED ${entry.key} skipped after a temporary fetch error: $error',
      );
      continue;
    }
    if (response.statusCode != 200) {
      stderr.writeln(
        'FRED ${entry.key} skipped with HTTP ${response.statusCode}.',
      );
      continue;
    }
    final lines = const LineSplitter().convert(response.body);
    final rows = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      final columns = line.split(',');
      if (columns.length < 2) continue;
      final value = double.tryParse(columns[1]);
      if (value == null || value.isNaN) continue;
      rows.add({
        'source_name': 'FRED / U.S. Bureau of Labor Statistics',
        'source_url': 'https://fred.stlouisfed.org/series/${entry.key}',
        'dataset_id': 'fred_${entry.key}',
        'series': entry.value,
        'observed_on': columns[0],
        'index_value': value,
        'base_year': 1982,
      });
    }
    if (api != null) {
      for (final chunk in _chunks(rows, 500)) {
        await api.upsert(
          'price_index_observations',
          chunk,
          onConflict: 'dataset_id,series,observed_on',
        );
      }
    }
    count += rows.length;
  }
  return count;
}

Future<int> _importWorkforceSkills(
  http.Client client,
  _SupabaseRestClient? api,
) async {
  final response = await client
      .get(
        Uri.parse(_workforceSkillsApiUrl),
        headers: {'User-Agent': 'IndustryHub-LiveDataImporter/1.0'},
      )
      .timeout(const Duration(seconds: 45));
  if (response.statusCode != 200) {
    throw StateError(
      'DOSM workforce-skills API returned HTTP ${response.statusCode}.',
    );
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! List) {
    throw const FormatException(
      'DOSM workforce-skills response was not a list.',
    );
  }
  final rows = decoded
      .whereType<Map>()
      .map((raw) {
        final data = Map<String, dynamic>.from(raw);
        final value = data['sru'] is num
            ? (data['sru'] as num).toDouble()
            : double.tryParse('${data['sru'] ?? ''}');
        final observedOn = '${data['date'] ?? ''}'.trim();
        final variable = '${data['variable'] ?? ''}'.trim();
        final ageGroup = '${data['age'] ?? 'Overall'}'.trim();
        if (value == null || observedOn.isEmpty || variable.isEmpty) {
          return null;
        }
        return <String, dynamic>{
          'source_name': 'Department of Statistics Malaysia',
          'source_url': 'https://data.gov.my/data-catalogue/lfs_qtr_sru_age',
          'dataset_id': 'lfs_qtr_sru_age',
          'variable': variable,
          'age_group': ageGroup,
          'observed_on': observedOn,
          'signal_value': value,
          'unit': variable.toLowerCase().contains('rate')
              ? 'percent'
              : "persons ('000)",
        };
      })
      .whereType<Map<String, dynamic>>()
      .toList();
  if (api != null) {
    for (final chunk in _chunks(rows, 500)) {
      await api.upsert(
        'workforce_skill_signals',
        chunk,
        onConflict: 'dataset_id,variable,age_group,observed_on',
      );
    }
  }
  return rows.length;
}

Future<int> _importPpi(http.Client client, _SupabaseRestClient? api) async {
  final response = await client
      .get(
        Uri.parse(_ppiCsvUrl),
        headers: {'User-Agent': 'IndustryHub-LiveDataImporter/1.0'},
      )
      .timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw StateError('DOSM PPI returned HTTP ${response.statusCode}.');
  }
  final lines = const LineSplitter().convert(response.body);
  if (lines.length < 2) return 0;
  final rows = <Map<String, dynamic>>[];
  for (final line in lines.skip(1)) {
    final columns = line.split(',');
    if (columns.length < 3 || columns[0] != 'abs') continue;
    final value = double.tryParse(columns[2]);
    if (value == null) continue;
    rows.add({
      'source_name': 'Department of Statistics Malaysia',
      'source_url': 'https://data.gov.my/data-catalogue/ppi',
      'dataset_id': 'ppi',
      'series': columns[0],
      'observed_on': columns[1],
      'index_value': value,
      'base_year': 2010,
    });
  }
  if (api != null) {
    for (final chunk in _chunks(rows, 500)) {
      await api.upsert(
        'price_index_observations',
        chunk,
        onConflict: 'dataset_id,series,observed_on',
      );
    }
  }
  return rows.length;
}

Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
  for (var index = 0; index < values.length; index += size) {
    yield values.sublist(index, (index + size).clamp(0, values.length));
  }
}

String _cleanText(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

class _SupabaseRestClient {
  _SupabaseRestClient(this.baseUrl, this.serviceRoleKey);

  final Uri baseUrl;
  final String serviceRoleKey;
  final http.Client _client = http.Client();

  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
  }) async {
    if (rows.isEmpty) return;
    var endpoint = baseUrl.resolve('/rest/v1/$table');
    if (onConflict != null && onConflict.isNotEmpty) {
      endpoint = endpoint.replace(queryParameters: {'on_conflict': onConflict});
    }
    final response = await _client
        .post(
          endpoint,
          headers: {
            'apikey': serviceRoleKey,
            'Authorization': 'Bearer $serviceRoleKey',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: jsonEncode(rows),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase upsert into $table failed with HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }
}
