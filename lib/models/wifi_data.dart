import 'package:json_annotation/json_annotation.dart';

part 'wifi_data.g.dart';

@JsonSerializable()
class WiFiData {
  const WiFiData({this.ssid = "", this.pass = "",this.start_ap = false});
  final String ssid;
  final String pass;
  final bool start_ap;


  factory WiFiData.fromJson(Map<String,dynamic> json) => _$WiFiDataFromJson(json);

  Map<String,dynamic> toJson() => _$WiFiDataToJson(this);
}