class DailySummaryResult {
  final String path;
  final String mode;

  DailySummaryResult({required this.path, required this.mode});

  factory DailySummaryResult.fromJson(Map<String, dynamic> json) {
    return DailySummaryResult(
      path: (json['path'] ?? '') as String,
      mode: (json['mode'] ?? '') as String,
    );
  }
}
