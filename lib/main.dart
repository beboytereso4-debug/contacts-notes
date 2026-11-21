import 'package:flutter/material.dart';

import 'screens/contact_list_screen.dart';

void main() {
  runApp(const ContactsBookApp());
}

class ContactsBookApp extends StatelessWidget {
  const ContactsBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const ContactListScreen(),
    );
  }
}
