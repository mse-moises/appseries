import 'package:json_annotation/json_annotation.dart';

part 'health_status.g.dart';

/// Answer of `GET /health` — `{"status": "ok"}`.
@JsonSerializable()
class HealthStatus {
  const HealthStatus({required this.status});

  factory HealthStatus.fromJson(Map<String, dynamic> json) => _$HealthStatusFromJson(json);

  final String status;

  Map<String, dynamic> toJson() => _$HealthStatusToJson(this);
}
