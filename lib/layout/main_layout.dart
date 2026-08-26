import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({required this.name, this.appbarActions = const [],this.floatingActionButton,required this.body, super.key});

  final String name;
  final List<Widget> appbarActions;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          style: GoogleFonts.caveat(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        actions: appbarActions,
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.black87, Colors.black],
            ),
          ),
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}