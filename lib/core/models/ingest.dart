class IngestResult {
  final String status;
  final String jobId;

  IngestResult({required this.status, required this.jobId});

  factory IngestResult.fromJson(Map<String, dynamic> json) {
    return IngestResult(
      status: json['status'] as String,
      jobId: json['job_id'] as String,
    );
  }
}
