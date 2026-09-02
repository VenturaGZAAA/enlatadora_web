// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wifi_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WiFiData _$WiFiDataFromJson(Map<String, dynamic> json) => WiFiData(
  ssid: json['ssid'] as String? ?? "",
  pass: json['pass'] as String? ?? "",
  start_ap: json['start_ap'] as bool? ?? false,
);

Map<String, dynamic> _$WiFiDataToJson(WiFiData instance) => <String, dynamic>{
  'ssid': instance.ssid,
  'pass': instance.pass,
  'start_ap': instance.start_ap,
};
