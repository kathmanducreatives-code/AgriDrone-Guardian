class PhotoModel {
  final String id;
  final String flightId;
  final String imageId;
  final int patchIndex;
  final String? capturedAt;
  final String? storagePath;
  final String? storageFolder;
  final String? previewUrl;
  final String uploadStatus;
  final String analysisStatus;
  final Map<String, dynamic>? primaryDetection;
  final int detectionCount;
  final String? highestSeverity;
  final String? cropType;
  final String? contentType;
  final String? uploadedAt;
  final String? processedAt;

  PhotoModel({
    required this.id,
    required this.flightId,
    required this.imageId,
    required this.patchIndex,
    this.capturedAt,
    this.storagePath,
    this.storageFolder,
    this.previewUrl,
    this.uploadStatus = 'unknown',
    this.analysisStatus = 'unknown',
    this.primaryDetection,
    this.detectionCount = 0,
    this.highestSeverity,
    this.cropType,
    this.contentType,
    this.uploadedAt,
    this.processedAt,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id']?.toString() ?? '',
      flightId: json['flight_id']?.toString() ?? '',
      imageId: json['image_id']?.toString() ?? '',
      patchIndex: (json['patch_index'] as num?)?.toInt() ?? 0,
      capturedAt: json['captured_at']?.toString(),
      storagePath: json['storage_path']?.toString(),
      storageFolder: json['storage_folder']?.toString(),
      previewUrl: json['preview_url']?.toString(),
      uploadStatus: json['upload_status']?.toString() ?? 'unknown',
      analysisStatus: json['analysis_status']?.toString() ?? 'unknown',
      primaryDetection: json['primary_detection'] as Map<String, dynamic>?,
      detectionCount: (json['detection_count'] as num?)?.toInt() ?? 0,
      highestSeverity: json['highest_severity']?.toString(),
      cropType: json['crop_type']?.toString(),
      contentType: json['content_type']?.toString(),
      uploadedAt: json['uploaded_at']?.toString(),
      processedAt: json['processed_at']?.toString(),
    );
  }

  /// Parse a friendly label from a storage_folder name like
  /// "mission_20260429_143022_a3f9" → "29 Apr 2026 · 14:30"
  static String folderLabel(String folder) {
    final match = RegExp(r'mission_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})').firstMatch(folder);
    if (match == null) return folder;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final day = match.group(3);
    final month = months[(int.tryParse(match.group(2)!) ?? 1) - 1];
    final year = match.group(1);
    final h = match.group(4);
    final m = match.group(5);
    return '$day $month $year · $h:$m';
  }
}
