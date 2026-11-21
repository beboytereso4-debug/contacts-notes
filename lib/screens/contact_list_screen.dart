import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/contact.dart';
import 'contact_form_screen.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<Contact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = await _db.getContacts(query: _searchController.text);
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _openForm([Contact? contact]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContactFormScreen(contact: contact)),
    );
    if (saved == true) _loadContacts();
  }

  Future<void> _toggleFavorite(Contact contact) async {
    await _db.update(contact.copyWith(isFavorite: !contact.isFavorite));
    _loadContacts();
  }

  Future<void> _delete(Contact contact) async {
    await _db.delete(contact.id!);
    setState(() => _contacts.removeWhere((c) => c.id == contact.id));

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${contact.name} deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await _db.insert(contact);
              _loadContacts();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search name, phone or email',
              leading: const Icon(Icons.search),
              onChanged: (_) => _loadContacts(),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _loadContacts();
                    },
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_contacts.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No contacts yet.\nTap + to add one.'
              : 'No matches found.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return Dismissible(
          key: ValueKey(contact.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _delete(contact),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(contact.name.isEmpty ? '?' : contact.name[0].toUpperCase()),
            ),
            title: Text(contact.name),
            subtitle: Text(
              contact.email.isEmpty ? contact.phone : '${contact.phone}\n${contact.email}',
            ),
            isThreeLine: contact.email.isNotEmpty,
            trailing: IconButton(
              icon: Icon(
                contact.isFavorite ? Icons.star : Icons.star_border,
                color: contact.isFavorite ? Colors.amber : null,
              ),
              onPressed: () => _toggleFavorite(contact),
            ),
            onTap: () => _openForm(contact),
          ),
        );
      },
    );
  }
}
