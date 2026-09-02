// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'WifiData.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WiFiData _$WiFiDataFromJson(Map<String, dynamic> json) => WiFiData(
  ssid: json['ssid'] as String? ?? "",
  pass: json['pass'] as String? ?? "",
  startAP: json['startAP'] as bool? ?? false,
);

Map<String, dynamic> _$WiFiDataToJson(WiFiData instance) => <String, dynamic>{
  'ssid': instance.ssid,
  'pass': instance.pass,
  'startAP': instance.startAP,
};
