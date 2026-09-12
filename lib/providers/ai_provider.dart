import 'dart:io';
import '../models/ai_provider_config.dart';
import '../models/damage_report.dart';

/// Common instruction sent to every provider so the JSON shape is
/// consistent regardless of which backend answers it.
const String kDamageAnalysisPrompt = '''
You are a vehicle damage inspection assistant. Look carefully at the supplied
image(s) of a vehicle and identify visible exterior damage only (dents,
scratches, cracks, broken lights/mirrors, misaligned panels, rust holes,
missing parts). Do not guess mechanical/internal issues you cannot see.

Respond with ONLY valid JSON (no markdown fences, no prose) in exactly this
shape:

{
  "summary": "one or two sentence overview in English",
  "summary_km": "same overview translated to Khmer",
  "items": [
    {
      "part": "English part name, e.g. Front Bumper",
      "part_km": "Khmer label for that part",
      "damage_type": "dent | scratch | crack | broken_light | misaligned | rust | missing_part | other",
      "severity": "minor | moderate | severe",
      "confidence": 0.0,
      "notes": "short optional note"
    }
  ]
}

Rules:
- "confidence" is YOUR estimate (0.0 to 1.0) of how sure you are about that
  specific finding. Be honest and conservative — do not inflate confidence.
- If you see no damage, return an empty "items" array and say so in "summary".
- If image quality, angle, or lighting limits what you can assess, say so in
  "summary" and lower confidence accordingly.
''';

/// Common interface every AI backend adapter implements. The rest of the
/// app only talks to this interface, so adding a new provider means writing
/// one new class and registering it in AIProviderFactory.
abstract class AIProvider {
  final AIProviderConfig config;
  const AIProvider(this.config);

  /// Sends one or more images (a burst from a video, or a single photo) to
  /// the provider and returns the parsed damage report.
  Future<DamageReport> analyzeImages(
    List<File> images, {
    String? extraContext,
  });

  String get label => config.kind.label;
}
