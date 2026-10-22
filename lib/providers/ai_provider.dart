import 'dart:io';
import 'package:dio/dio.dart';
import '../models/ai_provider_config.dart';
import '../models/damage_report.dart';

export '../models/ai_provider_config.dart';

/// Common instruction sent to every provider so the JSON shape is
/// consistent regardless of which backend answers it.
const String kDamageAnalysisPrompt = '''
You are an expert automotive & commercial vehicle inspector, appraiser, and mechanical acoustic diagnostic specialist.
Examine the supplied image(s), video keyframes, and any included audio track of the vehicle (passenger car, pickup, small truck, heavy truck, commercial equipment, or motorcycle).

You must detect and analyze EVERYTHING about the vehicle:
1. VEHICLE SPECIFICATIONS & IDENTITY:
   - Make & model (e.g., Toyota Hilux, Ford Ranger, Isuzu D-Max, Honda Civic, Scania R500).
   - Estimated year / generation.
   - Body style / type (Sedan, SUV, Pickup, Box Truck, Dump Truck, Van, Motorcycle, Heavy Machinery).
   - Exterior paint color (primary and trim).
   - License plate / registration plate number & jurisdiction (if visible).
   - VIN / Chassis number (if visible on dash plaque or engine bay).
   - Odometer reading in km (if instrument cluster photo is present).

2. OVERALL CONDITION & ROADWORTHINESS:
   - Overall condition score (0 to 100).
   - Condition grade ("A" = Excellent/Like New, "B" = Good/Normal Wear, "C" = Fair/Needs Service, "D" = Poor/Extensive Defects, "F" = Inoperable/Hazardous).
   - Roadworthiness assessment ("Roadworthy", "Needs Attention / Service", or "Unsafe / Do Not Drive").
   - Estimated repair cost bracket ("Minor", "Moderate", "Major").

3. MECHANICAL SOUND & ACOUSTIC ANALYSIS (if an audio track is included or sound was recorded):
   - Listen to the engine, exhaust, belts, and brakes.
   - Detect engine knock / rod knock / piston slap (metallic tapping synced to RPM).
   - Detect valve lifter ticking, timing chain rattle, serpentine belt squeal/chirp.
   - Detect exhaust manifold/gasket leaks, turbocharger whistle/whine, rough idle / cylinder misfire.
   - Detect brake squeal or metal-on-metal rotor grinding.
   - Assign an acoustic health score (0 to 100) and identify exact anomalies with diagnostic advice.

4. MULTI-ZONE DEFECTS & FAULTS (Inspect ALL 7 zones):
   - Engine Bay & Machine (oil/coolant/fuel/hydraulic leaks, belt wear, hose cracks, corroded battery, loose wiring).
   - Undercarriage, Frame, Suspension & Brakes (frame bends/cracks, leaf spring/shock damage, brake rotor wear).
   - Commercial Equipment (cargo bed, hydraulic rams/hoses, tail lift, hitch/fifth-wheel).
   - Cockpit & Dashboard (warning lights e.g. Check Engine, ABS, Airbag, Oil Pressure; interior wear).
   - Exterior Body & Glass (dents, scratches, cracks, misaligned panels, broken lamps, mirrors, rust/corrosion, paint peeling).
   - Wheels & Tires (tread depth, sidewall bulges/cuts, curb rash, rim cracks).

Respond with ONLY valid JSON (no markdown fences, no conversational prose) in exactly this shape:

{
  "summary": "comprehensive 2-3 sentence diagnostic overview in English",
  "summary_km": "accurate translation of the overview in natural Khmer script (ភាសាខ្មែរ)",
  "vehicle_identity": {
    "make": "Toyota",
    "model": "Hilux Revo",
    "year_range": "2019-2022",
    "body_type": "Pickup",
    "body_type_km": "រថយន្តភីកអាប់ (Pickup)",
    "color": "White",
    "color_km": "ពណ៌ស",
    "license_plate": "2AZ-1234 or null",
    "vin": "VIN or null",
    "odometer_reading": 85000 or null
  },
  "health_assessment": {
    "condition_score": 82,
    "condition_grade": "B",
    "roadworthiness": "Roadworthy | Needs Attention | Unsafe",
    "roadworthiness_km": "មានសុវត្ថិភាពអាចបើកបរបាន | ត្រូវការការថែទាំ | គ្រោះថ្នាក់",
    "repair_cost_tier": "Minor | Moderate | Major",
    "repair_cost_tier_km": "ស្រាល (កម្រិតទាប) | មធ្យម | ខ្ពស់"
  },
  "acoustic_analysis": {
    "audio_track_detected": true,
    "acoustic_health_score": 88,
    "engine_sound_profile": "Normal Idle | Belt Squeal | Engine Knock | Exhaust Leak | Valve Tick | Rough Idle",
    "engine_sound_profile_km": "ដំណើរការរលូនធម្មតា | សំឡេងកកិតខ្សែពាន | សំឡេងគោះក្នុងម៉ាស៊ីន | សំឡេងលេចធ្លាយស៊ីមាំង",
    "audio_summary": "English description of acoustic findings or engine sound",
    "audio_summary_km": "ការពិពណ៌នាសំឡេងម៉ាស៊ីនជាភាសាខ្មែរ",
    "anomalies": [
      {
        "anomaly_type": "belt_squeal | engine_knock | exhaust_leak | valve_tick | brake_squeal | rough_idle | other",
        "anomaly_type_km": "Khmer defect sound label",
        "timestamp_seconds": 2.5,
        "severity": "minor | moderate | severe",
        "severity_km": "ស្រាល | មធ្យម | ធ្ងន់ធ្ងរ",
        "confidence": 0.85,
        "diagnostic_advice": "Inspect serpentine belt tensioner and belt ribs for cracking.",
        "diagnostic_advice_km": "ពិនិត្យតង់ស្យុងខ្សែពាន និងស្នាមប្រេះលើខ្សែពានម៉ាស៊ីន។"
      }
    ]
  },
  "items": [
    {
      "part": "English part or system name, e.g. Front Bumper, Front Left Tire, Hydraulic Cylinder & Lines, Engine Valve Cover",
      "part_km": "Khmer label for that part, e.g. កាងមុខ, សំបកកង់ខាងឆ្វេងមុខ, ទុយោ និងស៊ីឡាំងអ៊ីដ្រូលីក, គម្របម៉ាស៊ីន",
      "damage_type": "engine_fault | fluid_leak | mechanical_wear | electrical_fault | warning_light | suspension_fault | hydraulic_fault | tire_damage | dent | scratch | crack | broken_light | misaligned | rust | missing_part | paint_chipping | other",
      "damage_type_km": "Khmer label for the fault type",
      "severity": "minor | moderate | severe",
      "severity_km": "ស្រាល | មធ្យម | ធ្ងន់ធ្ងរ",
      "confidence": 0.85,
      "box_2d": [620, 150, 890, 420],
      "image_index": 0,
      "notes": "concise English diagnostic description",
      "notes_km": "ការពិពណ៌នាលម្អិតជាភាសាខ្មែរ"
    }
  ]
}

Rules:
- ALWAYS populate every "_km" field in natural, grammatically correct Khmer script (ភាសាខ្មែរ, Unicode U+1780..U+17FF).
- STRICT LANGUAGE RULE: NEVER use any Thai characters (U+0E00..U+0E7F) or Lao characters in any "_km" field. Every "_km" field must be 100% pure Khmer script.
- AUTO-CROP & BOUNDING BOX: For every visible vehicle component or defect (such as Tires, Hydraulic lines, Brakes, Suspension, Body panels, Dents, Scratches), ALWAYS include "box_2d": [ymin, xmin, ymax, xmax] normalized to 0-1000 integer range and "image_index" (0-based index of the inspected image) so the system can automatically crop and highlight the component.
- IMPORTANT FOR SOUND & AUDIO DAMAGE: Whenever mechanical sound abnormalities (such as engine knock, belt squeal, exhaust blowing, valve lifter tick, rough idle, brake grind) are detected in the video audio, you MUST include those faults BOTH in "acoustic_analysis.anomalies" AND as items in the "items" array so they are listed as detected vehicle defects.
- If no audio track was provided or no sound was detectable, set "audio_track_detected": false, "acoustic_health_score": 100, and "anomalies": [].
- "confidence" is YOUR estimate (0.0 to 1.0) of how sure you are about that specific finding. Be conservative.
- If you see no damage items, return an empty "items" array and state so in summary/summary_km.
''';

/// Common interface every AI backend adapter implements. The rest of the
/// app only talks to this interface, so adding a new provider means writing
/// one new class and registering it in AIProviderFactory.
abstract class AIProvider {
  final AIProviderConfig config;
  const AIProvider(this.config);

  /// Sends one or more images (a burst from a video, or a single photo) and
  /// optional audio track to the provider and returns the parsed damage report.
  Future<DamageReport> analyzeImages(
    List<File> images, {
    File? audioFile,
    String? extraContext,
    CancelToken? cancelToken,
  });

  /// Fetches available models from the provider endpoint.
  Future<List<String>> loadModels();

  String get label => config.kind.label;
}
