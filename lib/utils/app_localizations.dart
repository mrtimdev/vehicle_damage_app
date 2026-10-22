import '../models/damage_report.dart';

/// Supported UI locales in the app. Defaults to Khmer (`km`).
enum AppLanguage { km, en }

extension AppLanguageX on AppLanguage {
  bool get isKhmer => this == AppLanguage.km;

  String get code => this == AppLanguage.km ? 'km' : 'en';

  String get displayName => this == AppLanguage.km ? 'ភាសាខ្មែរ' : 'English';

  String get toggleLabel => this == AppLanguage.km ? 'ខ្មែរ' : 'EN';
}

/// Comprehensive Khmer & English localization and automotive defect terminology
/// translator for the Vehicle Damage Analyzer app.
class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get isKm => lang == AppLanguage.km;

  // Navigation Bar
  String get navHome => isKm ? 'ទំព័រដើម' : 'Home';
  String get navAnalyze => isKm ? 'វិភាគ' : 'Analyze';
  String get navHistory => isKm ? 'ប្រវត្តិ' : 'History';
  String get navReports => isKm ? 'របាយការណ៍' : 'Reports';
  String get navSettings => isKm ? 'ការកំណត់' : 'Settings';

  // Header Subtitle
  String get headerAiSubtitle => isKm
      ? 'ប្រព័ន្ធ AI វិភាគរូបភាព និងសំឡេងម៉ាស៊ីន'
      : 'AI Powered • Multimodal Audio & Vision Inspection';

  // Hero Banner ("Detect Faults Before They Happen")
  String get aiScannerReady =>
      isKm ? 'ប្រព័ន្ធស្កេន AI រួចរាល់' : 'AI Vehicle Scanner Ready';
  String get heroDetectFaults => isKm ? 'រកឃើញកំហុសរថយន្ត' : 'Detect Faults';
  String get heroBeforeTheyHappen =>
      isKm ? 'មុនពេលខូចខាតធ្ងន់ធ្ងរ' : 'Before They Happen';
  String get visionInspection => isKm ? 'វិភាគ\nរូបភាព' : 'Vision\nInspection';
  String get audioAnalysis => isKm ? 'វិភាគ\nសំឡេង' : 'Audio\nAnalysis';
  String get aiEngine => isKm ? 'ម៉ាស៊ីន\nAI' : 'AI\nEngine';

  // Quick Action Subtitles
  String get takePhotoToAnalyze =>
      isKm ? 'ថតរូបផ្ទាល់ដើម្បីវិភាគ' : 'Take a photo to analyze';
  String get fromYourGallery => isKm ? 'ពីកម្មវិធីរូបភាព' : 'From your gallery';

  // Vehicle Zone Selector
  String get zoneFullVehicle => isKm ? 'រថយន្តទាំងមូល' : 'Full Vehicle';
  String get zoneEngine => isKm ? 'ម៉ាស៊ីន' : 'Engine';
  String get zoneTire => isKm ? 'កង់' : 'Tire';
  String get zoneBrake => isKm ? 'ហ្វ្រាំង' : 'Brake';
  String get zoneUndercarriage => isKm ? 'បាតក្រោម' : 'Undercarriage';
  String get zoneCustom => isKm ? 'ផ្ទាល់ខ្លួន' : 'Custom';
  String get inspectionTargetCardSub => isKm
      ? 'ចុចកំណត់តំបន់ ប្រភេទកំហុស សំឡេង និងការកំណត់'
      : 'Tap to configure target zone, audio & inspection settings.';

  // Quick Inspection Templates
  String get quickInspectionTemplates =>
      isKm ? 'គំរូត្រួតពិនិត្យរហ័ស' : 'Quick Inspection Templates';
  String get viewAll => isKm ? 'មើលទាំងអស់' : 'View All';
  String get templateDefault =>
      isKm ? 'ស្តង់ដារ\n(ពិនិត្យទូទៅ)' : 'Default\n(Full Check)';
  String get templateHeavyTruck => isKm ? 'រថយន្តធុនធ្ងន់' : 'Heavy Truck';
  String get templatePickupTruck => isKm ? 'រថយន្តភីកអាប់' : 'Pickup Truck';
  String get templateBusCoach =>
      isKm ? 'រថយន្តក្រុង / ទេសចរណ៍' : 'Bus & Coach';

  // App Branding & Splash Screen
  String get appBrandName => 'SV - Vehicle Fault Detection';
  String get appTitle => isKm
      ? 'SV - ពិនិត្យកំហុស និងការខូចខាតរថយន្ត'
      : 'SV - Vehicle Fault Detection';
  String get splashSubtitle => isKm
      ? 'ប្រព័ន្ធ AI វិភាគកំហុស និងការខូចខាតរថយន្ត'
      : 'AI-Powered Automotive Diagnostic & Fault Scanner';
  String get splashStatusText => isKm
      ? 'កំពុងចាប់ផ្តើមប្រព័ន្ធស្កេន AI...'
      : 'Initializing AI Diagnostic Scanner...';
  String get providerNotConfiguredTap => isKm
      ? 'មិនទាន់កំណត់ AI · ចុចដើម្បីកំណត់'
      : 'AI Provider not configured · Tap to set up';
  String get clearAll => isKm ? 'សម្អាតទាំងអស់' : 'Clear All';
  String get aiProviderRequiredTitle =>
      isKm ? 'ទាមទារការកំណត់ប្រព័ន្ធ AI' : 'AI Vision Provider Required';
  String get aiProviderRequiredSubtitle => isKm
      ? 'សូមបញ្ចូល API Key និងជ្រើសរើសម៉ូដែលនៅក្នុងការកំណត់។'
      : 'Configure your API key & model in AI Engine settings.';
  String get setupBtn => isKm ? 'កំណត់' : 'Setup';

  String stagedPhotosTitle(int count) =>
      isKm ? 'រូបភាពបានជ្រើសរើស ($count)' : 'Staged Photos ($count)';
  String get vehicleImageryCaptureTitle =>
      isKm ? 'ថត ឬបញ្ចូលរូបភាពរថយន្ត' : 'Vehicle Imagery Capture';
  String get stagedPhotosSubtitle => isKm
      ? 'ចុចលើរូបភាពណាមួយដើម្បីពង្រីកមើលលម្អិត'
      : 'Tap any photo to inspect full resolution';
  String get captureSubtitle => isKm
      ? 'ថតរូបភាពជុំវិញ និងរូបភាពជិតៗនៃស្នាមខូចខាតលើរថយន្ត'
      : 'Capture wide angles and close-ups of vehicle defects';
  String get autoOptimized => isKm ? 'បង្រួមស្វ័យប្រវត្តិ' : 'Auto-Optimized';
  String get addMore => isKm ? 'បន្ថែមទៀត' : 'Add More';
  String get snapPhoto => isKm ? 'ថតរូបភាព' : 'Snap Photo';
  String get importPhotos => isKm ? 'ជ្រើសរើសរូបភាព' : 'Import Photos';
  String get cameraShort => isKm ? 'កាមេរ៉ា' : 'Camera';
  String get importGalleryShort => isKm ? 'ឃ្លាំងរូបភាព' : 'Import Gallery';
  String get recordVideoClip => isKm ? 'ថតវីដេអូខ្លី' : 'Record Video Clip';
  String get importVideo => isKm ? 'បញ្ចូលវីដេអូ' : 'Import Video';
  String get videoClipStaged => isKm
      ? 'បានជ្រើសរើសវីដេអូសម្រាប់ស្រង់រូបភាពវិភាគ'
      : 'Video clip staged for keyframe inspection';

  String get addVehicleMediaTitle =>
      isKm ? 'បន្ថែមរូបភាពរថយន្ត' : 'Add Vehicle Media';
  String get takePhotoWithCamera =>
      isKm ? 'ថតរូបដោយប្រើកាមេរ៉ា' : 'Take Photo with Camera';
  String get takePhotoWithCameraSub => isKm
      ? 'ថតរូបជិត ឬរូបភាពទូលាយនៃផ្នែករថយន្ត'
      : 'Snap close-up or wide-angle vehicle views';
  String get chooseFromLibrary =>
      isKm ? 'ជ្រើសរើសពីកម្មវិធីរូបភាព' : 'Choose from Photo Library';
  String get chooseFromLibrarySub => isKm
      ? 'ជ្រើសរើសរូបភាពរថយន្តច្រើនសន្លឹកក្នុងពេលតែមួយ'
      : 'Select multiple vehicle photos at once';
  String get importFromUrl =>
      isKm ? 'បញ្ចូលពីតំណ URL' : 'Import from URL';
  String get importFromUrlSub => isKm
      ? 'គាំទ្រតំណ YouTube / Shorts វីដេអូ (MP4) ឬរូបភាព (JPG/PNG)'
      : 'Supports YouTube / Shorts, video (MP4/MOV), or image links';
  String get importUrlShort => isKm ? 'តំណ URL' : 'From URL';
  String get importUrlDialogTitle => isKm
      ? 'បញ្ចូលរូបភាព ឬវីដេអូតាមតំណ URL'
      : 'Import Image or Video from URL';
  String get importUrlDialogSubtitle => isKm
      ? 'បិទភ្ជាប់តំណ YouTube / Shorts ឬតំណផ្ទាល់នៃរូបភាព/វីដេអូរថយន្ត ដើម្បីស្រង់រូបភាពវិភាគដោយ AI។'
      : 'Paste a YouTube / Shorts link or a direct image/video URL to extract keyframes for AI analysis.';
  String get importUrlHint => isKm
      ? 'https://youtube.com/shorts/... ឬ .jpg / .mp4'
      : 'https://youtube.com/shorts/... or .jpg / .mp4';
  String get pasteBtn => isKm ? 'បិទភ្ជាប់' : 'Paste';
  String get downloadAndStageBtn =>
      isKm ? 'ទាញយក និងបញ្ចូល' : 'Download & Stage';
  String get extractFramesBtn =>
      isKm ? 'ស្រង់រូបភាពពីវីដេអូ' : 'Extract Keyframes';
  String get downloadingFromUrlStatus => isKm
      ? 'កំពុងទាញយកពីតំណ URL...'
      : 'Downloading media from URL...';
  String extractedVideoFramesSnack(int count) => isKm
      ? 'បានស្រង់រូបភាពចំនួន $count សន្លឹកពីវីដេអូរួចរាល់!'
      : 'Extracted $count keyframes from video!';
  String get importedImageFromUrlSnack => isKm
      ? 'បានទាញយករូបភាពពីតំណ URL រួចរាល់!'
      : 'Image downloaded from URL and staged!';

  String get inspectionTargetTitle => isKm
      ? 'គោលដៅត្រួតពិនិត្យ និងប្រភេទកំហុស'
      : 'Inspection Target & Defect Focus';
  String get inspectionTargetSubtitle => isKm
      ? 'ជ្រើសរើសតំបន់រថយន្ត ឬប្រភេទការខូចខាតដើម្បីឱ្យ AI វិភាគកាន់តែច្បាស់'
      : 'Guide AI detection toward specific zones or damage types';
  String get resetBtn => isKm ? 'កំណត់ឡើងវិញ' : 'Reset';
  String get vehicleZoneHeader => isKm ? 'តំបន់រថយន្ត' : 'VEHICLE ZONE';
  String get defectFocusHeader =>
      isKm ? 'ប្រភេទការខូចខាត' : 'DEFECT FOCUS TAGS';

  String get contextNotesTitle => isKm
      ? 'បរិបទបន្ថែម / កំណត់សម្គាល់ហេតុការណ៍'
      : 'Diagnostic Context / Incident Notes';
  String get contextNotesSubtitle => isKm
      ? 'ព័ត៌មានបន្ថែមសម្រាប់ជំនួយដល់ការវិភាគរបស់ AI (មិនចាំបាច់)'
      : 'Optional extra details to assist the AI inspector';
  String get contextNotesHint => isKm
      ? 'ឧ. "ប៉ះទង្គិចកាងមុខខាងស្តាំ សូមពិនិត្យមើលចង្កៀង និងគម្លាតទ្វារ"'
      : 'e.g., "Front right bumper impact, check headlamp mount and panel gap"';

  String get guidanceFooter => isKm
      ? 'ការវិភាគដោយប្រព័ន្ធ AI៖ លទ្ធផលបង្ហាញពីកម្រិតធ្ងន់ធ្ងរ និងភាគរយនៃភាពត្រឹមត្រូវ។ សូមត្រួតពិនិត្យផ្ទាល់បន្ថែមលើចំណុចសំខាន់ៗនៃគ្រោងរថយន្ត។'
      : 'Assistive AI Defect Diagnostics: Visual detection provides severity ratings and confidence percentages. Always perform physical inspection on structural safety points.';

  String detectButtonWithCount(int photoCount, bool isVideo) {
    if (isKm) {
      return isVideo
          ? 'ចាប់ផ្តើមវិភាគកំហុសរថយន្ត (វីដេអូ)'
          : 'ចាប់ផ្តើមវិភាគកំហុសរថយន្ត ($photoCount រូបភាព)';
    }
    return 'Detect Vehicle Faults (${isVideo ? "Video" : "$photoCount Photo${photoCount > 1 ? 's' : ''}"})';
  }

  String get detectButtonDefault => isKm
      ? 'ចាប់ផ្តើមវិភាគកំហុស និងការខូចខាតរថយន្ត'
      : 'Detect Vehicle Faults & Damage';

  String stepProgressLabel(int step) => isKm
      ? 'ជំហានទី $step នៃ 3 · កំពុងដំណើរការវិភាគរូបភាពដោយ AI'
      : 'Step $step of 3 · Multi-defect vision pipeline';
  String get cancelBtn => isKm ? 'បោះបង់' : 'Cancel';

  // Report Screen
  String get diagnosticReportTitle =>
      isKm ? 'របាយការណ៍វិភាគការខូចខាត' : 'Diagnostic Report';
  String get summaryCardTitle =>
      isKm ? 'សេចក្តីសង្ខេបនៃការត្រួតពិនិត្យ' : 'Inspection Summary';
  String get shareReportTooltip =>
      isKm ? 'ចែករំលែករបាយការណ៍' : 'Share Report';
  String photoIndexBadge(int current, int total) =>
      isKm ? 'រូបទី $current នៃ $total' : 'Photo $current of $total';
  String get tapToZoom => isKm ? 'ចុចដើម្បីពង្រីក' : 'Tap to zoom';
  String confidenceBadge(int pct) =>
      isKm ? 'ភាពត្រឹមត្រូវ $pct%' : '$pct% Confidence';
  String get lowConfidenceWarning => isKm
      ? 'ចំណុចដែលមានសញ្ញាទង់ជាតិ មានភាពត្រឹមត្រូវក្រោម 60% គួរត្រួតពិនិត្យផ្ទាល់បន្ថែម។'
      : 'Items flagged with a review badge have <60% confidence and should be verified manually.';

  String detectedFindingsHeader(int count) =>
      isKm ? 'លទ្ធផលរកឃើញ ($count)' : 'Detected Findings ($count)';
  String get showAllBtn => isKm ? 'បង្ហាញទាំងអស់' : 'Show All';

  String filterAll(int count) =>
      isKm ? 'ទាំងអស់ ($count)' : 'All ($count)';
  String filterSevere(int count) =>
      isKm ? 'ធ្ងន់ធ្ងរ ($count)' : 'Severe ($count)';
  String filterModerate(int count) =>
      isKm ? 'មធ្យម ($count)' : 'Moderate ($count)';
  String filterMinor(int count) =>
      isKm ? 'ស្រាល ($count)' : 'Minor ($count)';

  String get severeCardTitle => isKm ? 'ធ្ងន់ធ្ងរ' : 'Severe';
  String get moderateCardTitle => isKm ? 'មធ្យម' : 'Moderate';
  String get minorCardTitle => isKm ? 'ស្រាល' : 'Minor';

  String get noDefectsTitle => isKm
      ? 'មិនរកឃើញកំហុស ឬការខូចខាតលើរថយន្តទេ'
      : 'No Vehicle Faults or Damage Detected';
  String get noDefectsSubtitle => isKm
      ? 'ការត្រួតពិនិត្យដោយ AI មិនបានរកឃើញកំហុសម៉ាស៊ីន ការលេចធ្លាយ ស្នាមកំពិត ស្នាមឆ្កូត ស្នាមប្រេះ ឬការខូចខាតនៅក្នុងរូបភាពនេះទេ។'
      : 'The AI vision inspection did not identify visible mechanical faults, leaks, dents, scratches, cracks, or structural issues in the submitted imagery.';
  String get emptyFilterMessage => isKm
      ? 'មិនមានលទ្ធផលត្រូវនឹងកម្រិតធ្ងន់ធ្ងរដែលបានជ្រើសរើសទេ។'
      : 'No findings match the selected severity filter.';

  String get verifyManuallyBadge =>
      isKm ? 'ពិនិត្យផ្ទាល់បន្ថែម' : 'Verify Manually';
  String get confidenceLabel => isKm ? 'ភាពត្រឹមត្រូវ' : 'Confidence';
  String get descriptionLabel => isKm ? 'ការពិពណ៌នា' : 'Description';

  // Audio Readout / Listen (TTS) & Toggle EN/KM labels
  String get listenKhmerBtn => 'ស្ដាប់ខ្មែរ';
  String get listenEnglishBtn => 'Listen EN';
  String get stopListeningBtn => isKm ? 'បញ្ឈប់' : 'Stop';
  String get showSecondaryLangBtn => isKm ? 'បង្ហាញ EN' : 'Show ខ្មែរ';
  String get hideSecondaryLangBtn => isKm ? 'លាក់ EN' : 'Hide ខ្មែរ';
  String get listenSummaryKhmer => 'ស្ដាប់សង្ខេប (ខ្មែរ)';
  String get listenSummaryEnglish => 'Listen Summary (EN)';
  String get listenAllKhmerTooltip => 'ស្ដាប់របាយការណ៍ទាំងមូលជាភាសាខ្មែរ';
  String get listenAllEnglishTooltip => 'Listen to full report in English';

  String get rawPayloadTitle =>
      isKm ? 'ទិន្នន័យដើមពី AI (JSON)' : 'Raw AI Vision Payload';
  String get rawPayloadSubtitle => isKm
      ? 'មើលទិន្នន័យ JSON ដែលបានមកពីម៉ូដែល AI'
      : 'Inspect raw structured JSON returned by the model';
  String get copyJsonBtn => isKm ? 'ចម្លង JSON' : 'Copy JSON';

  // History Screen
  String get historyTitle =>
      isKm ? 'ប្រវត្តិការត្រួតពិនិត្យ' : 'Inspection History';
  String get kpiInspections => isKm ? 'ការពិនិត្យសរុប' : 'Inspections';
  String get kpiDefectsLogged => isKm ? 'កំហុសរកឃើញ' : 'Defects Logged';
  String get kpiAvgConfidence => isKm ? 'ភាពត្រឹមត្រូវមធ្យម' : 'Avg Confidence';
  String get searchHistoryHint => isKm
      ? 'ស្វែងរកតាមផ្នែករថយន្ត ប្រភេទកំហុស ឬម៉ូដែល AI...'
      : 'Search by part, defect, or AI model...';
  String get filterSevereFaults => isKm ? 'មានកំហុសធ្ងន់ធ្ងរ' : 'Severe Faults';
  String get filterCleanOnly => isKm ? 'គ្មានកំហុស (0)' : 'Clean (0 Faults)';
  String get filterNeedsReview =>
      isKm ? 'ត្រូវពិនិត្យបន្ថែម' : 'Needs Review';
  String get cleanVehicleInspection =>
      isKm ? 'រថយន្តគ្មានស្នាមខូចខាត' : 'Clean Vehicle Inspection';
  String defectsDetectedCount(int count) => isKm
      ? 'រកឃើញកំហុស $count ចំណុច'
      : '$count Defect${count > 1 ? 's' : ''} Detected';
  String get noFaultsBadge => isKm ? 'គ្មានកំហុស' : 'No Faults';
  String get emptyHistoryTitle =>
      isKm ? 'មិនទាន់មានប្រវត្តិត្រួតពិនិត្យនៅឡើយទេ' : 'No Inspection History Yet';
  String get emptyHistorySubtitle => isKm
      ? 'ថត ឬបញ្ចូលរូបភាពរថយន្តនៅក្នុងផ្ទាំងវិភាគ ដើម្បីបង្កើតរបាយការណ៍វិភាគដំបូងរបស់អ្នក។'
      : 'Capture or upload vehicle photos on the Analyze tab to generate your first AI fault diagnostic report.';
  String get startFirstInspectionBtn =>
      isKm ? 'ចាប់ផ្តើមការត្រួតពិនិត្យដំបូង' : 'Start First Inspection';

  // Settings Screen
  String get settingsTitle =>
      isKm ? 'ការកំណត់ប្រព័ន្ធ AI' : 'AI Engine Configuration';
  String get settingsResetTooltip =>
      isKm ? 'កំណត់លំនាំដើមឡើងវិញ' : 'Reset to Provider Defaults';
  String get statusReadyTitle =>
      isKm ? 'រួចរាល់សម្រាប់ការវិភាគ' : 'Ready for Fault Detection';
  String get statusNeedsKeyTitle =>
      isKm ? 'ទាមទារការបញ្ចូល API Key' : 'API Key Required';
  String get statusNeedsKeySub => isKm
      ? 'សូមបញ្ចូល API Key ខាងក្រោមដើម្បីបើកដំណើរការវិភាគរូបភាពរថយន្ត។'
      : 'Enter your provider API key below to enable vehicle imagery analysis.';
  String get appearanceLanguageTitle =>
      isKm ? 'រូបរាង និងភាសា' : 'Appearance & Language';
  String get appearanceLanguageSubtitle => isKm
      ? 'ប្តូរពណ៌ផ្ទៃកម្មវិធី និងភាសាបង្ហាញ'
      : 'Customize visual theme and display language';
  String get themeSystem => isKm ? 'តាមប្រព័ន្ធ' : 'System';
  String get themeLight => isKm ? 'ភ្លឺ' : 'Light';
  String get themeDark => isKm ? 'ងងឹត' : 'Dark';
  String get uiLanguageLabel =>
      isKm ? 'ភាសាបង្ហាញក្នុងកម្មវិធី' : 'Interface Language';
  String get aiProviderTitle =>
      isKm ? 'ក្រុមហ៊ុនផ្តល់សេវា AI' : 'AI Vision Provider';
  String get aiProviderSubtitle => isKm
      ? 'ជ្រើសរើសប្រព័ន្ធ AI សម្រាប់វិភាគរូបភាពរថយន្ត'
      : 'Select the vision engine used to inspect vehicle imagery';
  String get credentialsTitle =>
      isKm ? 'តំណភ្ជាប់ និង API Key' : 'Endpoint & API Credentials';
  String get baseUrlLabel => isKm ? 'អាសយដ្ឋាន API (Base URL)' : 'API Base URL';
  String get apiKeyOptionalLabel => isKm
      ? 'API Key (មិនចាំបាច់សម្រាប់ម៉ាស៊ីនផ្ទាល់ខ្លួន)'
      : 'API Key (Optional for local servers)';
  String get apiKeyRequiredLabel =>
      isKm ? 'កូនសោសម្ងាត់ (API Key)' : 'Secret API Key';
  String get pasteTooltip =>
      isKm ? 'បិទភ្ជាប់ពី Clipboard' : 'Paste from clipboard';
  String get modelSelectionTitle =>
      isKm ? 'ជ្រើសរើសម៉ូដែល AI' : 'Model Selection';
  String get modelSelectionSubtitle => isKm
      ? 'ជ្រើសរើសម៉ូដែលដែលមានស្រាប់ ឬទាញយកម៉ូដែលពី API'
      : 'Choose a preset model or sync live models from the API';
  String get presetsBtn => isKm ? 'បញ្ជីម៉ូដែល' : 'Presets';
  String get customIdBtn => isKm ? 'បញ្ចូលឈ្មោះផ្ទាល់' : 'Custom ID';
  String get activeModelLabel =>
      isKm ? 'ម៉ូដែល AI កំពុងប្រើប្រាស់' : 'Active Vision Model';
  String get customModelLabel =>
      isKm ? 'ឈ្មោះម៉ូដែល AI (Custom ID)' : 'Custom Model Identifier';
  String connectingToProvider(String provider) =>
      isKm ? 'កំពុងភ្ជាប់ទៅកាន់ $provider...' : 'Connecting to $provider...';
  String get loadModelsBtn => isKm ? 'ទាញយកបញ្ជីម៉ូដែល' : 'Load Models';
  String get securityNote => isKm
      ? 'ប្រព័ន្ធរក្សាទុកសុវត្ថិភាព៖ API Key របស់អ្នកត្រូវបានរក្សាទុកដោយសុវត្ថិភាពក្នុងឧបករណ៍ និងបញ្ជូនផ្ទាល់ទៅកាន់ក្រុមហ៊ុនផ្តល់សេវា AI។'
      : 'Hardware-Encrypted Storage: Your API key is stored locally inside iOS Keychain / Android Keystore and sent directly to your configured provider.';
  String get saveSettingsBtn => isKm ? 'រក្សាទុកការកំណត់' : 'Save Settings';
  String get settingsSavedToast =>
      isKm ? 'បានរក្សាទុកការកំណត់ AI រួចរាល់' : 'AI configuration saved';

  String get selectAllTagsBtn => isKm ? 'ជ្រើសរើសទាំងអស់' : 'Select All';
  String get clearAllTagsBtn => isKm ? 'ដកចេញទាំងអស់' : 'Clear All';
  String get configureBtn => isKm ? 'កំណត់ជម្រើស' : 'Configure';
  String get doneBtn => isKm ? 'រួចរាល់' : 'Done';
  String get allTagsActive =>
      isKm ? 'បានជ្រើសគ្រប់ប្រភេទកំហុស (13)' : 'All 13 defect types active';
  String activeTagsCount(int count, int total) => isKm
      ? '$count/$total ប្រភេទកំហុស'
      : '$count of $total defect types active';
  String get scopeModalTitle =>
      isKm ? 'កំណត់គោលដៅត្រួតពិនិត្យ និងកំហុស' : 'Inspection Scope & Defect Focus';
  String get scopeModalSubtitle => isKm
      ? 'ជ្រើសរើសផ្នែករថយន្ត និងប្រភេទកំហុសដែលត្រូវឱ្យ AI វិភាគ'
      : 'Select vehicle zones and specific defect categories to analyze';
  String get inspectionScopeSettingsTile =>
      isKm ? 'គោលដៅត្រួតពិនិត្យ និងប្រភេទកំហុស' : 'Inspection Scope & Focus Tags';
  String get inspectionScopeSettingsSubtitle => isKm
      ? 'កំណត់ផ្នែករថយន្ត និងប្រភេទកំហុសលំនាំដើមសម្រាប់ការវិភាគ'
      : 'Configure active vehicle zones and defect focus categories';

  /// Translates preset inspection areas into Khmer when in Khmer locale.
  String translateArea(String area) {
    if (!isKm) return area;
    switch (area) {
      case 'Full Vehicle (All Systems & Machine)':
        return 'រថយន្តទាំងមូល (គ្រប់ផ្នែក និងម៉ាស៊ីន)';
      case 'Engine & Machine Bay':
        return 'ម៉ាស៊ីន និងប្រព័ន្ធមេកានិច';
      case 'Suspension, Brakes & Chassis':
        return 'ជើងក្រោម ហ្វ្រាំង និងគ្រោងឆ្អឹង';
      case 'Electrical, Battery & Wiring':
        return 'ប្រព័ន្ធភ្លើង អាគុយ និងខ្សែភ្លើង';
      case 'Dashboard & Warning Lights':
        return 'តាប្លូ និងភ្លើងសញ្ញាព្រមាន';
      case 'Cargo Bed, Box & Hydraulics':
        return 'ទ្រុងឡានដឹកទំនិញ និងប្រព័ន្ធបូម';
      case 'Interior & Cabin':
        return 'ផ្នែកខាងក្នុងកាប៊ីនរថយន្ត';
      case 'All Exterior (360°)':
        return 'ផ្នែកខាងក្រៅទាំងអស់ (360°)';
      case 'Front Bumper & Grille':
        return 'កាងមុខ និងប៉ាណាមុខ';
      case 'Rear Bumper & Trunk':
        return 'កាងក្រោយ និងគូទក្រោយ';
      case 'Doors & Side Panels':
        return 'ទ្វារ និងតួចំហៀង';
      case 'Lights & Glass':
        return 'ចង្កៀង និងកញ្ចក់';
      case 'Wheels & Tires':
        return 'កង់ និងយ៉ាន់';
      case 'Underbody & Frame':
        return 'បាតក្រោម និងគ្រោងឆ្អឹង';
      default:
        return area;
    }
  }

  // Vehicle Identity & Condition Strings
  String get vehicleIdentityTitle =>
      isKm ? 'ព័ត៌មានអត្តសញ្ញាណរថយន្ត' : 'Vehicle Identity & Attributes';
  String get vehicleMakeModel =>
      isKm ? 'ម៉ាក និងម៉ូដែល' : 'Make & Model';
  String get bodyTypeLabel =>
      isKm ? 'ប្រភេទតួរថយន្ត' : 'Body Style';
  String get vehicleColorLabel =>
      isKm ? 'ពណ៌រថយន្ត' : 'Vehicle Color';
  String get licensePlateLabel =>
      isKm ? 'ស្លាកលេខសម្គាល់' : 'License Plate';
  String get vinLabel =>
      isKm ? 'លេខសម្គាល់តួ (VIN)' : 'Chassis / VIN';
  String get odometerLabel =>
      isKm ? 'ចម្ងាយធ្វើដំណើរ' : 'Odometer Reading';
  String get healthScoreTitle =>
      isKm ? 'ពិន្ទុ និងលក្ខខណ្ឌបើកបរ' : 'Vehicle Condition & Roadworthiness';
  String get healthScoreLabel =>
      isKm ? 'ពិន្ទុស្ថានភាព' : 'Condition Score';
  String get roadworthinessLabel =>
      isKm ? 'លក្ខខណ្ឌសុវត្ថិភាព' : 'Roadworthiness';
  String get estimatedRepairTierLabel =>
      isKm ? 'កម្រិតការចំណាយជួសជុល' : 'Repair Cost Bracket';

  // Acoustic & Sound Analysis Strings
  String get acousticAnalysisTitle =>
      isKm ? 'ការវិភាគសំឡេងម៉ាស៊ីន និងមេកានិច' : 'Acoustic & Mechanical Sound Analysis';
  String get acousticAnalysisSubtitle => isKm
      ? 'វិភាគសំឡេងម៉ាស៊ីន ស៊ីមាំង និងហ្វ្រាំងដែលស្រង់ចេញពីវីដេអូ'
      : 'Diagnoses engine knock, belts, exhaust, and brakes from video audio';
  String get analyzeWithAudioLabel =>
      isKm ? 'វិភាគរួមបញ្ចូលសំឡេងម៉ាស៊ីន (Sound Analysis)' : 'Analyze with Vehicle Audio';
  String get analyzeWithAudioSubtitle => isKm
      ? 'ពិនិត្យសំឡេងគោះម៉ាស៊ីន ខ្សែពាន ស៊ីមាំង និងហ្វ្រាំងពីវីដេអូ'
      : 'Diagnose engine knock, belt squeal, exhaust leaks & brake noise';
  String get soundDetectedDefectBadge =>
      isKm ? 'រកឃើញតាមសំឡេង 🔊' : 'Detected via Sound 🔊';
  String get soundStatusNormal => isKm
      ? 'សំឡេងម៉ាស៊ីនដំណើរការធម្មតា (គ្មានសំឡេងខូចខាត)'
      : 'Engine Sound Normal (No mechanical anomalies detected)';
  String get soundStatusSilent => isKm
      ? 'មិនឮសំឡេងម៉ាស៊ីនច្បាស់ក្នុងវីដេអូ'
      : 'No clear engine sound detected in video';
  String get engineSoundProfileLabel =>
      isKm ? 'ទម្រង់សំឡេងម៉ាស៊ីន' : 'Engine Sound Profile';
  String get acousticHealthScoreLabel =>
      isKm ? 'ពិន្ទុគុណភាពសំឡេង' : 'Acoustic Health';
  String get soundAnomaliesTitle =>
      isKm ? 'បញ្ហាសំឡេងមិនប្រក្រតី' : 'Detected Sound Anomalies';
  String get audioTrackActive =>
      isKm ? 'បានស្រង់សំឡេងពីវីដេអូរួចរាល់ 🔊' : 'Audio Track Extracted 🔊';
  String get audioAnalysisRunning =>
      isKm ? 'កំពុងវិភាគសំឡេងម៉ាស៊ីន...' : 'Analyzing vehicle sound track...';
  String get inspectionVideoTitle =>
      isKm ? 'វីដេអូត្រួតពិនិត្យរថយន្ត' : 'Vehicle Inspection Video';
  String get playVideoBtn => isKm ? 'ចាក់វីដេអូ' : 'Play Video';
  String get pauseVideoBtn => isKm ? 'ផ្អាក' : 'Pause';
  String get previewVideoTitle => isKm ? 'មើលវីដេអូ' : 'Preview Video';
  String get previewVideoTooltip =>
      isKm ? 'មើលវីដេអូដែលបានជ្រើសរើស' : 'Watch staged video';
  String get playExtractedAudioBtn =>
      isKm ? 'ស្តាប់សំឡេងម៉ាស៊ីនដែលស្រង់បាន' : 'Listen to Extracted Vehicle Audio';
  String get stopExtractedAudioBtn =>
      isKm ? 'បញ្ឈប់ការចាក់សំឡេង' : 'Stop Audio';
  String get extractedFramesHeader =>
      isKm ? 'រូបភាពដែលស្រង់ចេញពីវីដេអូ' : 'Extracted Inspection Frames';

  // Auto-Crop Parts Settings & UI
  String get autoCropPartsTitle =>
      isKm ? 'កាត់ស្វ័យប្រវត្តិនូវគ្រឿងបន្លាស់' : 'Auto-Crop Vehicle Parts';
  String get autoCropPartsSubtitle => isKm
      ? 'កាត់យករូបភាពលម្អិតនៃគ្រឿងបន្លាស់ (កង់ អ៊ីដ្រូលីក ម៉ាស៊ីន ហ្វ្រាំង និងតួ)'
      : 'Automatically crop and highlight focused images of Tires, Hydraulics, Engine, Brakes, and Body';
  String get autoCropEnabledBadge => isKm ? 'បើក' : 'Enabled';
  String get autoCropDisabledBadge => isKm ? 'បិទ' : 'Disabled';
  String get croppedPartViewTitle =>
      isKm ? 'រូបភាពកាត់លម្អិត' : 'Cropped Part';
  String get vehicleContextTitle =>
      isKm ? 'ទីតាំងលើរថយន្ត' : 'Vehicle Context';
  String get tapToInspectCropLocation =>
      isKm ? 'ចុចដើម្បីមើលរូបភាពកាត់ និងទីតាំង' : 'Tap to inspect crop & location';
  String get pinchToZoomHint =>
      isKm ? 'ពង្រីក/បង្រួមដោយប្រើម្រាមដៃពីរ' : 'Pinch to zoom and inspect';

  /// Translates preset defect tags into Khmer when in Khmer locale.
  String translateDefectTag(String tag) {
    if (!isKm) return tag;
    switch (tag) {
      case 'Engine / Machine Fault':
        return 'កំហុសម៉ាស៊ីន និងមេកានិច';
      case 'Fluid / Oil Leak':
        return 'លេចធ្លាយប្រេង / ទឹកស្អំ';
      case 'Suspension / Brake Wear':
        return 'បញ្ហាជើងក្រោម និងហ្វ្រាំង';
      case 'Electrical / Battery':
        return 'បញ្ហាប្រព័ន្ធភ្លើង និងអាគុយ';
      case 'Dashboard Warning':
        return 'ភ្លើងសញ្ញាព្រមានលើតាប្លូ';
      case 'Hydraulic / Cargo Fault':
        return 'បញ្ហាប្រព័ន្ធបូម និងទ្រុងឡាន';
      case 'Dents & Creases':
        return 'ស្នាមកំពិត និងផត';
      case 'Deep Scratches':
        return 'ស្នាមឆ្កូតជ្រៅ';
      case 'Cracked Glass':
        return 'ប្រេះ ឬបែកកញ្ចក់';
      case 'Broken Lamp/Mirror':
        return 'បែកចង្កៀង / កញ្ចក់មើលក្រោយ';
      case 'Panel Misalignment':
        return 'ខុសគម្លាតតួរថយន្ត';
      case 'Rust / Corrosion':
        return 'ច្រេះ និងពុកផុយ';
      case 'Paint Chipping':
        return 'របក ឬហើរថ្នាំពណ៌';
      default:
        return tag;
    }
  }
}

/// Translates automotive severity levels, defect types (e.g. Rust, Crack, Dent),
/// part names, and diagnostic descriptions into pure Khmer (`ភាសាខ្មែរ`).
class KhmerAutomotiveTranslator {
  static final RegExp _thaiScriptRegex = RegExp(r'[\u0E00-\u0E7F]+');

  /// Strips any stray Thai Unicode characters (`U+0E00..U+0E7F`) that an AI
  /// model might accidentally emit and normalizes whitespace.
  static String sanitizeKhmer(String? input) {
    if (input == null || input.isEmpty) return '';
    return input
        .replaceAll(_thaiScriptRegex, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  /// Returns true if [input] contains any Thai Unicode characters.
  static bool containsThaiScript(String? input) {
    if (input == null || input.isEmpty) return false;
    return _thaiScriptRegex.hasMatch(input);
  }

  /// Returns the Khmer label for [DamageSeverity].
  static String severityKhmer(DamageSeverity s) {
    switch (s) {
      case DamageSeverity.minor:
        return 'ស្រាល';
      case DamageSeverity.moderate:
        return 'មធ្យម';
      case DamageSeverity.severe:
        return 'ធ្ងន់ធ្ងរ';
      case DamageSeverity.unknown:
        return 'មិនស្គាល់';
    }
  }

  /// Returns a bilingual Khmer + English severity label (e.g. `មធ្យម · Moderate`).
  static String severityBilingual(DamageSeverity s, {bool khmerOnly = false}) {
    final km = severityKhmer(s);
    if (khmerOnly) return km;
    return '$km · ${s.label}';
  }

  /// Translates common English vehicle part names into pure Khmer if `part_km`
  /// was omitted or sanitized.
  static String partNameKhmer(String rawPart, {String? aiProvidedKhmer}) {
    final cleanedAi = sanitizeKhmer(aiProvidedKhmer);
    if (cleanedAi.isNotEmpty) return cleanedAi;

    final lower = rawPart.toLowerCase().trim();
    if (lower.isEmpty) return 'ផ្នែករថយន្ត';

    if (lower.contains('engine') ||
        lower.contains('motor') ||
        lower.contains('cylinder') ||
        lower.contains('valve cover') ||
        lower.contains('turbo')) {
      return 'ម៉ាស៊ីនរថយន្ត';
    }
    if (lower.contains('radiator') ||
        lower.contains('intercooler') ||
        lower.contains('coolant')) {
      return 'ធុងទឹកស្អំ / ប្រព័ន្ធបញ្ចុះកម្ដៅ';
    }
    if (lower.contains('battery') ||
        lower.contains('alternator') ||
        lower.contains('wiring') ||
        lower.contains('harness') ||
        lower.contains('fuse')) {
      return 'អាគុយ និងប្រព័ន្ធខ្សែភ្លើង';
    }
    if (lower.contains('belt') ||
        lower.contains('hose') ||
        lower.contains('pulley')) {
      return 'ខ្សែពាន និងទុយោម៉ាស៊ីន';
    }
    if (lower.contains('dashboard') ||
        lower.contains('instrument cluster') ||
        lower.contains('gauge') ||
        lower.contains('warning light')) {
      return 'តាប្លូ និងភ្លើងសញ្ញាព្រមាន';
    }
    if (lower.contains('suspension') ||
        lower.contains('shock') ||
        lower.contains('strut') ||
        lower.contains('leaf spring') ||
        lower.contains('control arm') ||
        lower.contains('axle')) {
      return 'ប្រព័ន្ធជើងក្រោម និងប៉ុងរថយន្ត';
    }
    if (lower.contains('brake') ||
        lower.contains('rotor') ||
        lower.contains('caliper') ||
        lower.contains('drum')) {
      return 'ប្រព័ន្ធហ្វ្រាំង';
    }
    if (lower.contains('hydraulic') ||
        lower.contains('cargo') ||
        lower.contains('truck bed')) {
      return 'ទ្រុងឡាន និងប្រព័ន្ធបូមអ៊ីដ្រូលីក';
    }
    if (lower.contains('exhaust') || lower.contains('muffler')) {
      return 'បំពង់ស៊ីមាំង';
    }
    if (lower.contains('interior') ||
        lower.contains('seat') ||
        lower.contains('steering') ||
        lower.contains('cabin')) {
      return 'ផ្នែកខាងក្នុងកាប៊ីន';
    }
    if (lower.contains('windshield') || lower.contains('windscreen')) {
      return 'កញ្ចក់មុខរថយន្ត';
    }
    if (lower.contains('rear glass') || lower.contains('rear window')) {
      return 'កញ្ចក់ក្រោយរថយន្ត';
    }
    if (lower.contains('window') || lower.contains('glass')) {
      return 'កញ្ចក់រថយន្ត';
    }
    if (lower.contains('front') &&
        (lower.contains('grille') || lower.contains('support'))) {
      return 'ប៉ាណាមុខ / គ្រោងទ្រផ្នែកខាងក្រោម';
    }
    if (lower.contains('front bumper')) return 'កាងមុខ';
    if (lower.contains('rear bumper')) return 'កាងក្រោយ';
    if (lower.contains('bumper')) return 'កាងរថយន្ត';
    if (lower.contains('grille')) return 'ប៉ាណាមុខ';
    if (lower.contains('hood') || lower.contains('bonnet')) {
      return 'គម្របម៉ាស៊ីនមុខ (កាបូ)';
    }
    if (lower.contains('trunk') ||
        lower.contains('tailgate') ||
        lower.contains('boot')) {
      return 'គម្របគូទក្រោយ';
    }
    if (lower.contains('headlight') || lower.contains('headlamp')) {
      return 'ចង្កៀងមុខ';
    }
    if (lower.contains('taillight') || lower.contains('taillamp')) {
      return 'ចង្កៀងក្រោយ';
    }
    if (lower.contains('mirror')) return 'កញ្ចក់មើលក្រោយចំហៀង';
    if (lower.contains('front left door')) return 'ទ្វារមុខខាងឆ្វេង';
    if (lower.contains('front right door')) return 'ទ្វារមុខខាងស្តាំ';
    if (lower.contains('rear left door')) return 'ទ្វារក្រោយខាងឆ្វេង';
    if (lower.contains('rear right door')) return 'ទ្វារក្រោយខាងស្តាំ';
    if (lower.contains('door')) return 'ទ្វាររថយន្ត';
    if (lower.contains('fender') || lower.contains('quarter panel')) {
      return 'ថ្ពាល់រថយន្ត / តួចំហៀង';
    }
    if (lower.contains('roof')) return 'ដំបូលរថយន្ត';
    if (lower.contains('wheel') ||
        lower.contains('rim') ||
        lower.contains('tire')) {
      return 'កង់ និងយ៉ាន់រថយន្ត';
    }
    if (lower.contains('frame') ||
        lower.contains('underbody') ||
        lower.contains('chassis') ||
        lower.contains('bracket')) {
      return 'គ្រោងទ្រផ្នែកខាងក្រោម';
    }
    return 'ផ្នែករថយន្ត ($rawPart)';
  }

  /// Translates canonical or free-text `damageType` (e.g. `rust`, `crack`, `dent`)
  /// into natural Khmer automotive terminology.
  static String damageTypeKhmer(String rawType, {String? aiProvidedKhmer}) {
    final cleanedAi = sanitizeKhmer(aiProvidedKhmer);
    if (cleanedAi.isNotEmpty) {
      return cleanedAi;
    }
    final normalized = rawType.toLowerCase().replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'ការខូចខាតទូទៅ';

    // Exact or substring matches for vehicle & machine defect categories
    if (normalized.contains('leak') ||
        normalized.contains('oil') ||
        normalized.contains('coolant') ||
        normalized.contains('fluid')) {
      return 'លេចធ្លាយប្រេង / សារធាតុរាវ';
    }
    if (normalized.contains('engine') ||
        normalized.contains('mechanical') ||
        normalized.contains('wear') ||
        normalized.contains('belt') ||
        normalized.contains('hose')) {
      return 'កំហុសម៉ាស៊ីន / សឹករិចរិលមេកានិច';
    }
    if (normalized.contains('electric') ||
        normalized.contains('battery') ||
        normalized.contains('wiring')) {
      return 'បញ្ហាប្រព័ន្ធភ្លើង / អាគុយ';
    }
    if (normalized.contains('warning') ||
        normalized.contains('indicator') ||
        normalized.contains('dashboard')) {
      return 'ភ្លើងសញ្ញាព្រមានលើតាប្លូ';
    }
    if (normalized.contains('suspension') ||
        normalized.contains('brake') ||
        normalized.contains('axle') ||
        normalized.contains('chassis')) {
      return 'បញ្ហាជើងក្រោម / ហ្វ្រាំង';
    }
    if (normalized.contains('hydraulic') || normalized.contains('pump')) {
      return 'បញ្ហាប្រព័ន្ធបូមអ៊ីដ្រូលីក';
    }
    if (normalized.contains('rust') || normalized.contains('corros')) {
      return 'ច្រេះ និងពុកផុយ';
    }
    if (normalized.contains('crack') ||
        normalized.contains('shatter') ||
        normalized.contains('windshield')) {
      return 'ប្រេះបែក';
    }
    if (normalized.contains('dent') ||
        normalized.contains('crease') ||
        normalized.contains('crumple') ||
        normalized.contains('crush')) {
      return 'កំពិត / ផត';
    }
    if (normalized.contains('scratch') ||
        normalized.contains('scuff') ||
        normalized.contains('scrape') ||
        normalized.contains('abrasion')) {
      return 'ស្នាមឆ្កូត';
    }
    if (normalized.contains('broken light') ||
        normalized.contains('lamp') ||
        normalized.contains('headlight') ||
        normalized.contains('taillight')) {
      return 'បែកចង្កៀង';
    }
    if (normalized.contains('mirror')) {
      return 'បែកកញ្ចក់មើលក្រោយ';
    }
    if (normalized.contains('misalign') ||
        normalized.contains('gap') ||
        normalized.contains('bent') ||
        normalized.contains('warped') ||
        normalized.contains('deform')) {
      return 'ខុសគម្លាត / វៀច';
    }
    if (normalized.contains('missing') ||
        normalized.contains('detached') ||
        normalized.contains('torn')) {
      return 'បាត់បង់ផ្នែក / ដាច់';
    }
    if (normalized.contains('paint') ||
        normalized.contains('chip') ||
        normalized.contains('peel') ||
        normalized.contains('flak')) {
      return 'របកថ្នាំពណ៌';
    }
    if (normalized.contains('puncture') ||
        normalized.contains('flat') ||
        normalized.contains('tire')) {
      return 'ខូចខាតសំបកកង់';
    }
    if (normalized.contains('hole') || normalized.contains('perforat')) {
      return 'ធ្លុះធ្លាយ';
    }
    if (normalized == 'other' || normalized == 'unknown') {
      return 'ការខូចខាតផ្សេងៗ';
    }
    return 'ការខូចខាត ($rawType)';
  }

  /// Returns a clean single-locale label for a defect type (`ច្រេះ និងពុកផុយ` in Khmer, `Rust` in English).
  static String damageTypeDisplay(
    DamageItem item, {
    required AppLanguage lang,
  }) {
    if (lang.isKhmer) {
      return damageTypeKhmer(
        item.damageType,
        aiProvidedKhmer: item.damageTypeKhmer,
      );
    }
    return item.formattedDamageType;
  }

  /// Returns a Khmer diagnostic description for [item].
  /// Uses sanitized [item.notesKhmer] when provided by the AI model; if missing
  /// (such as in older reports saved before Khmer notes were added), translates
  /// common English automotive inspection terms into pure Khmer.
  static String resolveNotesKhmer(DamageItem item) {
    final direct = sanitizeKhmer(item.notesKhmer);
    if (direct.isNotEmpty) return direct;

    final rawNotes = item.notes?.trim() ?? '';
    final partKm = partNameKhmer(
      item.partName,
      aiProvidedKhmer: item.partNameKhmer,
    );
    final defectKm = damageTypeKhmer(
      item.damageType,
      aiProvidedKhmer: item.damageTypeKhmer,
    );
    final sevKm = severityKhmer(item.severity);

    if (rawNotes.isEmpty) {
      return 'រកឃើញ$defectKm កម្រិត$sevKm នៅលើ$partKm។';
    }

    // Translate common English automotive defect phrases for legacy saved reports
    final lower = rawNotes.toLowerCase();
    final details = <String>[];

    if (lower.contains('corrosion') || lower.contains('rust')) {
      details.add('មានស្នាមច្រេះ និងការពុកផុយនៃលោហៈ');
    }
    if (lower.contains('flaking paint') ||
        lower.contains('peeling paint') ||
        lower.contains('chipped paint') ||
        lower.contains('paint loss')) {
      details.add('មានការរបក ឬហើរថ្នាំពណ៌');
    }
    if (lower.contains('lower bracket') ||
        lower.contains('upright support') ||
        lower.contains('support')) {
      details.add('នៅលើជើងទ្រ និងគ្រោងទ្រផ្នែកខាងក្រោម');
    }
    if (lower.contains('no definite rust-through') ||
        lower.contains('surface rust')) {
      details.add('មិនទាន់ឃើញមានការធ្លុះធ្លាយគ្រោងឆ្អឹងទាំងស្រុងនៅឡើយទេ');
    }
    if (lower.contains('branching') ||
        lower.contains('crack-like') ||
        lower.contains('crack')) {
      details.add('ឃើញមានស្នាមប្រេះបែកជាខ្សែវែង');
    }
    if (lower.contains('upper windshield') || lower.contains('windshield')) {
      details.add('នៅលើផ្ទៃកញ្ចក់មុខ');
    }
    if (lower.contains('right side')) {
      details.add('ឆ្ពោះទៅផ្នែកខាងស្តាំ');
    } else if (lower.contains('left side')) {
      details.add('ឆ្ពោះទៅផ្នែកខាងឆ្វេង');
    }
    if (lower.contains('reflection') ||
        lower.contains('lighting') ||
        lower.contains('glare') ||
        lower.contains('limit certainty')) {
      details.add('ចំណាំងផ្លាតពន្លឺអាចកាត់បន្ថយភាពច្បាស់លាស់ខ្លះ');
    }
    if (lower.contains('deep scratch') || lower.contains('scratches')) {
      details.add('មានស្នាមឆ្កូតលើផ្ទៃថ្នាំ');
    }
    if (lower.contains('dent') ||
        lower.contains('crease') ||
        lower.contains('deformation')) {
      details.add('មានស្នាមកំពិត និងផតខូចទ្រង់ទ្រាយ');
    }
    if (lower.contains('misaligned') ||
        lower.contains('uneven gap') ||
        lower.contains('panel gap')) {
      details.add('មានគម្លាតមិនស្មើគ្នា ឬវៀចខុសទម្រង់ដើម');
    }
    if (lower.contains('missing') || lower.contains('detached')) {
      details.add('បាត់បង់ ឬដាច់ចេញពីទីតាំងដើម');
    }

    if (details.isNotEmpty) {
      return 'រកឃើញ$defectKm កម្រិត$sevKm លើ$partKm៖ ${details.join(" និង ")}។';
    }

    return 'រកឃើញ$defectKm កម្រិត$sevKm នៅលើ$partKm។ គួរត្រួតពិនិត្យផ្ទាល់បន្ថែម។';
  }

  /// Resolves or synthesizes a pure Khmer summary for [report].
  static String resolveSummaryKhmer(DamageReport report) {
    final cleaned = sanitizeKhmer(report.summaryKhmer);
    if (cleaned.isNotEmpty) return cleaned;
    if (report.items.isEmpty) {
      return 'ការត្រួតពិនិត្យដោយប្រព័ន្ធ AI មិនបានរកឃើញការខូចខាតផ្នែកខាងក្រៅនៅលើរថយន្តនេះទេ។';
    }
    final pct = (report.overallConfidence * 100).round();
    return 'រកឃើញចំណុចខូចខាតសរុបចំនួន ${report.items.length} ចំណុច (ធ្ងន់ធ្ងរ ${report.severeCount}, មធ្យម ${report.moderateCount}, ស្រាល ${report.minorCount}) ដោយមានភាពត្រឹមត្រូវរួម $pct%។';
  }

  /// Builds natural Khmer speech text for a single [DamageItem].
  static String buildFindingSpeechKhmer(DamageItem item, {int? index}) {
    final partKm = partNameKhmer(
      item.partName,
      aiProvidedKhmer: item.partNameKhmer,
    );
    final sevKm = severityKhmer(item.severity);
    final defectKm = damageTypeKhmer(
      item.damageType,
      aiProvidedKhmer: item.damageTypeKhmer,
    );
    final descKm = resolveNotesKhmer(item);
    final pct = (item.confidence * 100).round();
    final prefix = index != null ? 'ចំណុចទី $index៖ ' : '';
    return '$prefix$partKm។ កម្រិត$sevKm។ ប្រភេទកំហុស៖ $defectKm។ $descKm ភាពត្រឹមត្រូវ $pct ភាគរយ។';
  }

  /// Builds natural English speech text for a single [DamageItem].
  static String buildFindingSpeechEnglish(DamageItem item, {int? index}) {
    final partEn = item.partName.trim().isNotEmpty
        ? item.partName.trim()
        : 'Vehicle Part';
    final sevEn = item.severity.label;
    final defectEn = item.formattedDamageType;
    final descEn = (item.notes != null && item.notes!.trim().isNotEmpty)
        ? item.notes!.trim()
        : 'Detected $defectEn on $partEn.';
    final pct = (item.confidence * 100).round();
    final prefix = index != null ? 'Finding $index: ' : '';
    return '$prefix$partEn. Severity: $sevEn. Defect type: $defectEn. $descEn Confidence: $pct percent.';
  }

  /// Translates common vehicle body styles into Khmer.
  static String bodyTypeKhmer(String? raw) {
    final lower = (raw ?? '').toLowerCase().trim();
    if (lower.isEmpty) return 'រថយន្តទូទៅ';
    if (lower.contains('suv')) return 'រថយន្ត SUV';
    if (lower.contains('pickup')) return 'រថយន្តភីកអាប់ (Pickup)';
    if (lower.contains('sedan')) return 'រថយន្តទេសចរណ៍ (Sedan)';
    if (lower.contains('truck') || lower.contains('lorry')) return 'ឡានដឹកទំនិញ (Truck)';
    if (lower.contains('van') || lower.contains('minivan')) return 'រថយន្តវ៉ាន (Van)';
    if (lower.contains('motorcycle') || lower.contains('bike')) return 'ម៉ូតូ';
    if (lower.contains('machinery') || lower.contains('excavator')) return 'គ្រឿងចក្រ';
    return sanitizeKhmer(raw);
  }

  /// Translates roadworthiness states into Khmer.
  static String roadworthinessKhmer(String? raw) {
    final lower = (raw ?? '').toLowerCase().trim();
    if (lower.contains('unsafe') || lower.contains('danger') || lower.contains('hazard')) {
      return 'គ្រោះថ្នាក់ មិនគួរដំណើរការ';
    }
    if (lower.contains('roadworthy') || lower.contains('safe') || lower.contains('pass')) {
      return 'មានសុវត្ថិភាពអាចបើកបរបាន';
    }
    return 'ត្រូវការការថែទាំ ឬត្រួតពិនិត្យបន្ថែម';
  }

  /// Translates acoustic sound anomaly types into Khmer.
  static String acousticAnomalyKhmer(String? raw) {
    final lower = (raw ?? '').toLowerCase().trim();
    if (lower.contains('brake')) {
      return 'សំឡេងកកិតហ្វ្រាំង (Brake Noise)';
    }
    if (lower.contains('knock') || lower.contains('piston')) {
      return 'សំឡេងគោះក្នុងម៉ាស៊ីន (Engine Knock)';
    }
    if (lower.contains('squeal') || lower.contains('belt')) {
      return 'សំឡេងកកិតខ្សែពាន (Belt Squeal)';
    }
    if (lower.contains('exhaust') || lower.contains('leak')) {
      return 'សំឡេងលេចធ្លាយស៊ីមាំង (Exhaust Leak)';
    }
    if (lower.contains('tick') || lower.contains('valve')) {
      return 'សំឡេងរោទិ៍វ៉ាល់ម៉ាស៊ីន (Valve Tick)';
    }
    if (lower.contains('rough') || lower.contains('idle') || lower.contains('misfire')) {
      return 'សំឡេងម៉ាស៊ីនញ័រមិនស្មើ (Rough Idle)';
    }
    if (lower.contains('turbo') || lower.contains('whine')) {
      return 'សំឡេងទួរបូហួច (Turbo Whine)';
    }
    return sanitizeKhmer(raw);
  }

  /// Translates engine sound profiles into Khmer.
  static String engineSoundProfileKhmer(String? raw) {
    final lower = (raw ?? '').toLowerCase().trim();
    if (lower.contains('normal') || lower.contains('smooth')) {
      return 'ដំណើរការរលូនធម្មតា (Normal)';
    }
    if (lower.contains('severe') || lower.contains('critical')) {
      return 'រកឃើញសំឡេងខូចខាតធ្ងន់ធ្ងរ';
    }
    if (lower.contains('abnormal') || lower.contains('warning')) {
      return 'រកឃើញសំឡេងមិនប្រក្រតី';
    }
    return sanitizeKhmer(raw);
  }
}
