import 'package:json_annotation/json_annotation.dart';

part 'WifiData.g.dart';

@JsonSerializable()
class WiFiData {
  const WiFiData({this.ssid = "", this.pass = "",this.startAP = false});
  final String ssid;
  final String pass;
  final bool startAP;


  factory WiFiData.fromJson(Map<String,dynamic> json) => _$WiFiDataFromJson(json);

  Map<String,dynamic> toJson() => _$WiFiDataToJson(this);
}