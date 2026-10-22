import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:vehicle_damage_analyzer/models/ai_provider_config.dart';
import 'package:vehicle_damage_analyzer/models/damage_report.dart';

class MockBackendAdapter implements HttpClientAdapter {
  final Map<String, dynamic> modelsResponse;
  final Map<String, dynamic> inspectResponse;

  MockBackendAdapter({
    required this.modelsResponse,
    required this.inspectResponse,
  });

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    if (path.contains('/models')) {
      final jsonStr = jsonEncode(modelsResponse);
      return ResponseBody.fromString(
        jsonStr,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (path.contains('/chat/completions') || path.contains('/inspect')) {
      final contentStr = jsonEncode(inspectResponse);
      final openaiChatFormat = {
        'id': 'chatcmpl-backend-test',
        'object': 'chat.completion',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': contentStr,
            },
          }
        ],
      };

      return ResponseBody.fromString(
        jsonEncode(openaiChatFormat),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({'detail': 'Not Found'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('Vehicle AI Backend Integration Tests', () {
    const backendConfig = AIProviderConfig(
      kind: AIProviderKind.custom,
      baseUrl: 'http://localhost:8000',
      apiKey: '',
      model: 'multimodal-vehicle-analyzer',
    );

    final mockBackendReport = {
      'summary':
          'Acoustic analysis detected mechanical anomalies (belt squeal) on V8 Diesel engine operating around 720 RPM. Condition rated Normal with health score 91%.',
      'summary_km':
          'ការវិភាគសំឡេងបានរកឃើញកំហុសមេកានិច (សំឡេងកកិតខ្សែពាន) លើម៉ាស៊ីន V8 (ម៉ាស៊ូត) ដំណើរការប្រមាណ 720 RPM។',
      'vehicle_identity': {
        'make': 'Toyota',
        'model': 'Hilux Revo',
        'year_range': '2022',
        'body_type': 'Pickup',
        'body_type_km': 'រថយន្តភីកអាប់ (Pickup)',
        'color': 'White',
        'color_km': 'ពណ៌ស',
        'license_plate': '2AZ-8899',
        'vin': 'MR0HA3CD800123456',
        'odometer_reading': 34500,
      },
      'health_assessment': {
        'condition_score': 86,
        'condition_grade': 'B',
        'roadworthiness': 'Roadworthy',
        'roadworthiness_km': 'មានសុវត្ថិភាពអាចបើកបរបាន',
        'repair_cost_tier': 'Moderate',
        'repair_cost_tier_km': 'មធ្យម',
      },
      'acoustic_analysis': {
        'audio_track_detected': true,
        'acoustic_health_score': 91,
        'engine_sound_profile': 'Abnormal: Belt Squeal',
        'engine_sound_profile_km': 'ខុសប្រក្រតី៖ សំឡេងកកិតខ្សែពាន',
        'audio_summary': 'Mechanical belt friction detected during idle acceleration.',
        'audio_summary_km': 'បានរកឃើញសំឡេងកកិតខ្សែពានម៉ាស៊ីនពេលបង្កើនល្បឿន។',
        'anomalies': [
          {
            'anomaly_type': 'belt_squeal',
            'anomaly_type_km': 'សំឡេងកកិតខ្សែពាន',
            'timestamp_seconds': 1.8,
            'severity': 'moderate',
            'severity_km': 'មធ្យម',
            'confidence': 0.94,
            'diagnostic_advice': 'Inspect serpentine belt tensioner and replace worn belt.',
            'diagnostic_advice_km': 'ត្រួតពិនិត្យតង់ស្យុងខ្សែពាន និងប្តូរខ្សែពានដែលសឹក។',
          }
        ],
      },
      'items': [
        {
          'part': 'Engine Bay (Acoustic Diagnostics)',
          'part_km': 'ផ្នែកម៉ាស៊ីន (សំឡេង)',
          'damage_type': 'belt_squeal',
          'damage_type_km': 'សំឡេងកកិតខ្សែពាន',
          'severity': 'moderate',
          'severity_km': 'មធ្យម',
          'confidence': 0.94,
          'notes': 'Serpentine belt slipping under load at 1.8s.',
          'notes_km': 'ខ្សែពានម៉ាស៊ីនកកិតនៅវិនាទីទី ១.៨។',
        },
        {
          'part': 'Front Bumper',
          'part_km': 'កាងខាងមុខ',
          'damage_type': 'scratch',
          'damage_type_km': 'ស្នាមឆ្កូតលើកាងមុខ',
          'severity': 'minor',
          'severity_km': 'ស្រាល',
          'confidence': 0.88,
          'notes': 'Parking scrape on lower lip.',
          'notes_km': 'ស្នាមឆ្កូតពេលចូលចតលើកាងមុខផ្នែកក្រោម។',
        }
      ],
    };

    test('CustomProvider models list includes backend models', () {
      expect(backendConfig.kind.suggestedModels,
          contains('multimodal-vehicle-analyzer'));
      expect(backendConfig.kind.suggestedModels,
          contains('laion-clap-automotive'));
      expect(backendConfig.kind.suggestedModels,
          contains('echov2-anomaly-detector'));
      expect(backendConfig.kind.suggestedModels,
          contains('engine-sound-classifier'));
      expect(backendConfig.kind.suggestedModels,
          contains('clap-finetuned-custom'));
    });

    test('parses full backend multimodal report with acoustic analysis and vehicle identity', () {
      final report = DamageReport.fromJson(mockBackendReport);

      expect(report.summary, contains('Acoustic analysis detected'));
      expect(report.summaryKhmer, contains('ការវិភាគសំឡេង'));

      // Vehicle Identity (from backend)
      expect(report.vehicleIdentity?.make, equals('Toyota'));
      expect(report.vehicleIdentity?.model, equals('Hilux Revo'));
      expect(report.vehicleIdentity?.licensePlate, equals('2AZ-8899'));

      // Health Assessment (from backend)
      expect(report.healthAssessment?.conditionScore, equals(86));
      expect(report.healthAssessment?.conditionGrade, equals('B'));
      expect(report.healthAssessment?.isRoadworthy, isTrue);

      // Acoustic Analysis with the 4 models
      expect(report.acousticAnalysis?.audioTrackDetected, isTrue);
      expect(report.acousticAnalysis?.acousticHealthScore, equals(91));
      expect(report.acousticAnalysis?.engineSoundProfile, equals('Abnormal: Belt Squeal'));
      expect(report.hasAcousticAnomalies, isTrue);
      expect(report.acousticAnalysis?.anomalies.length, equals(1));

      final anomaly = report.acousticAnalysis!.anomalies.first;
      expect(anomaly.anomalyType, equals('belt_squeal'));
      expect(anomaly.timestampSeconds, equals(1.8));
      expect(anomaly.confidence, equals(0.94));
      expect(anomaly.severity, equals(DamageSeverity.moderate));

      // Items (vision + acoustic combined)
      expect(report.items.length, equals(2));
      expect(report.items.any((i) => i.damageType == 'belt_squeal'), isTrue);
      expect(report.items.any((i) => i.damageType == 'scratch'), isTrue);
    });
  });
}
