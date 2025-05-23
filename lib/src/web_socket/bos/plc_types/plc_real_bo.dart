import 'package:json_annotation/json_annotation.dart';

part 'plc_real_bo.g.dart';

@JsonSerializable()
class PlcRealBO {
  PlcRealBO({
    required this.value,
    this.dt = 'REAL',
  });

  factory PlcRealBO.fromJson(Map<String, dynamic> json) =>
      _$PlcRealBOFromJson(json);

  @JsonKey()
  final String dt;

  @JsonKey(name: 'val')
  final double value;

  Map<String, dynamic> toJson() => _$PlcRealBOToJson(this);
}
