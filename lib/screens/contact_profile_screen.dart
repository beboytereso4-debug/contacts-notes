import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/contact.dart';
import 'contact_form_screen.dart';

class ContactProfileScreen extends StatefulWidget {
  final Contact contact;

  const ContactProfileScreen({super.key, required this.contact});

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  late Contact _contact;
  final ImagePicker _imagePicker = ImagePicker();
  bool _changingPhoto = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
  }

  String get _initials {
    return _contact.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
  }

  Future<void> _editContact() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContactFormScreen(contact: _contact)),
    );
    if (saved != true || !mounted) return;

    final contacts = await DatabaseHelper.instance.getContacts();
    final updated = contacts.where((item) => item.id == _contact.id);
    if (!mounted) return;
    if (updated.isEmpty) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _contact = updated.first;
        _hasChanges = true;
      });
    }
  }

  Future<void> _changePhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (_contact.photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove profile photo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      final oldPath = _contact.photoPath;
      final updated = _contact.copyWith(clearPhoto: true);
      await DatabaseHelper.instance.update(updated);
      if (oldPath != null) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      if (mounted) {
        setState(() {
          _contact = updated;
          _hasChanges = true;
        });
      }
      return;
    }

    try {
      setState(() => _changingPhoto = true);
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked == null || !mounted) return;

      // Keep a private app copy so the photo remains available after restart
      // and even if the original gallery item is moved or deleted.
      final appDirectory = await getApplicationDocumentsDirectory();
      final photoDirectory =
          Directory(path.join(appDirectory.path, 'contact_photos'));
      await photoDirectory.create(recursive: true);
      final extension = path.extension(picked.path).isEmpty
          ? '.jpg'
          : path.extension(picked.path);
      final destination = path.join(
        photoDirectory.path,
        'contact_${_contact.id}_${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      await File(picked.path).copy(destination);

      final oldPath = _contact.photoPath;
      final updated = _contact.copyWith(photoPath: destination);
      await DatabaseHelper.instance.update(updated);
      if (oldPath != null) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      if (mounted) {
        setState(() {
          _contact = updated;
          _hasChanges = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the profile photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingPhoto = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final updated = _contact.copyWith(isFavorite: !_contact.isFavorite);
    await DatabaseHelper.instance.update(updated);
    if (mounted) {
      setState(() {
        _contact = updated;
        _hasChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanges);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contact profile'),
          actions: [
            IconButton(
              tooltip: 'Edit contact',
              onPressed: _editContact,
              icon: const Icon(Icons.edit_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _changingPhoto ? null : _changePhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          backgroundImage: _contact.photoPath != null &&
                                  File(_contact.photoPath!).existsSync()
                              ? FileImage(File(_contact.photoPath!))
                              : null,
                          child: _contact.photoPath == null ||
                                  !File(_contact.photoPath!).existsSync()
                              ? Text(
                                  _initials.isEmpty ? '?' : _initials,
                                  style: const TextStyle(
                                    color: Color(0xFF4056A1),
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF4056A1),
                            child: _changingPhoto
                                ? SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    size: 17, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _changingPhoto ? null : _changePhoto,
                    icon: const Icon(Icons.photo_library_outlined, size: 17),
                    label: const Text('Change photo'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _contact.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _contact.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFE4A52D),
                    ),
                    label: Text(_contact.isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'CONTACT DETAILS',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            _detailTile(
              icon: Icons.phone_outlined,
              label: 'Phone number',
              value: _contact.phone,
            ),
            if (_contact.email.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailTile(
                icon: Icons.mail_outline_rounded,
                label: 'Email address',
                value: _contact.email,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _editContact,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit contact details'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    )),
                const SizedBox(height: 4),
                SelectableText(value,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          Icon(
            icon == Icons.phone_outlined
                ? Icons.content_copy_rounded
                : Icons.alternate_email_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 18,
          ),
        ],
      ),
    );
  }
}
