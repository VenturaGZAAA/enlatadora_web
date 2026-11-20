import 'package:material_ui/material_ui.dart';
class MockData {
  const MockData(this.time, this.message);

  final DateTime time;
  final String message;

  static MockData now(String data){
    return MockData(DateTime.now(), data);
  }

  Widget view() {
    return ListTile(
      title: Text(message),
      subtitle: Text("${time.hour}-${time.minute}-${time.second}"),
    );
  }
}
