import 'package:json_annotation/json_annotation.dart';

part 'wifi_data.g.dart';

@JsonSerializable()
class WiFiData {
  const WiFiData({this.ssid = "", this.pass = "", this.start_ap = false});

  final String ssid;
  final String pass;
  final bool start_ap;

  factory WiFiData.fromJson(Map<String, dynamic> json) =>
      _$WiFiDataFromJson(json);

  Map<String, dynamic> toJson() => _$WiFiDataToJson(this);
}

@JsonSerializable()
class WiFiState {
  const WiFiState({required this.sta_connected, required this.start_ap});

  final bool start_ap;
  final bool sta_connected;

  factory WiFiState.fromJson(Map<String, dynamic> json) =>
      _$WiFiStateFromJson(json);

  Map<String, dynamic> toJson() => _$WiFiStateToJson(this);

  bool isInvalid(){
    return !start_ap && !sta_connected;
  }
}
