import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/contact.dart';

class ContactFormScreen extends StatefulWidget {
  final Contact? contact;

  const ContactFormScreen({super.key, this.contact});

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late bool _isFavorite;
  String? _photoPath;
  bool _pickingPhoto = false;
  bool _saving = false;

  bool get _isEditing => widget.contact != null;

  String get _initials {
    return _name.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
  }

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _name = TextEditingController(text: contact?.name ?? '');
    _phone = TextEditingController(text: contact?.phone ?? '');
    _email = TextEditingController(text: contact?.email ?? '');
    _isFavorite = contact?.isFavorite ?? false;
    _photoPath = contact?.photoPath;
    _name.addListener(_refreshInitials);
  }

  void _refreshInitials() {
    if (_photoPath == null || _photoPath!.isEmpty) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _name.removeListener(_refreshInitials);
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      setState(() => _pickingPhoto = true);
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked == null || !mounted) return;

      final appDirectory = await getApplicationDocumentsDirectory();
      final photoDirectory =
          Directory(path.join(appDirectory.path, 'contact_photos'));
      await photoDirectory.create(recursive: true);

      final extension = path.extension(picked.path).isEmpty
          ? '.jpg'
          : path.extension(picked.path);
      final destination = path.join(
        photoDirectory.path,
        'contact_draft_${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      await File(picked.path).copy(destination);

      if (!mounted) return;
      setState(() => _photoPath = destination);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not select the photo. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    final hasPhoto = _photoPath != null &&
        _photoPath!.isNotEmpty &&
        File(_photoPath!).existsSync();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD94B4B),
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Color(0xFFD94B4B)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final previousPhoto = widget.contact?.photoPath;
    final photoChanged = previousPhoto != null &&
        previousPhoto.isNotEmpty &&
        previousPhoto != _photoPath;

    final contact = Contact(
      id: widget.contact?.id,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      isFavorite: _isFavorite,
      createdAt: widget.contact?.createdAt,
      photoPath: _photoPath,
    );

    try {
      final db = DatabaseHelper.instance;
      if (_isEditing) {
        await db.update(contact);
      } else {
        await db.insert(contact);
      }

      if (photoChanged) {
        final oldFile = File(previousPhoto);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the contact. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFD94B4B),
          size: 30,
        ),
        title: const Text('Delete contact?'),
        content: Text(
          '${widget.contact!.name} will be permanently removed from your contacts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD94B4B),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await DatabaseHelper.instance.delete(widget.contact!.id!);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoPath != null &&
        _photoPath!.isNotEmpty &&
        File(_photoPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit contact' : 'New contact'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete contact',
              onPressed: _confirmDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFD94B4B),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickingPhoto ? null : _showPhotoOptions,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFE9EDFA),
                      backgroundImage:
                          hasPhoto ? FileImage(File(_photoPath!)) : null,
                      child: hasPhoto
                          ? null
                          : _initials.isNotEmpty
                              ? Text(
                                  _initials,
                                  style: const TextStyle(
                                    color: Color(0xFF4056A1),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 44,
                                  color: Color(0xFF4056A1),
                                ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF4056A1),
                        child: _pickingPhoto
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 17,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickingPhoto ? null : _showPhotoOptions,
              icon: const Icon(Icons.photo_library_outlined, size: 17),
              label: Text(hasPhoto ? 'Change photo' : 'Add profile photo'),
            ),
            const SizedBox(height: 12),
            const _SectionHeading(
              title: 'Contact information',
              subtitle: 'Fields marked with * are required.',
            ),
            const SizedBox(height: 16),
            _fieldLabel('Full name *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. Alex Johnson',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please enter a name'
                  : null,
            ),
            const SizedBox(height: 18),
            _fieldLabel('Phone number *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. 09XX XXX XXXX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please enter a phone number'
                  : null,
            ),
            const SizedBox(height: 18),
            _fieldLabel('Email address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'name@example.com (optional)',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                    ? null
                    : 'Please enter a valid email address';
              },
            ),
            const SizedBox(height: 26),
            const _SectionHeading(
              title: 'Quick preferences',
              subtitle: 'Mark important people as favorites.',
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE7E9F1)),
              ),
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                secondary: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFE4A52D),
                ),
                title: const Text(
                  'Add to favorites',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Show this person in your favorites list',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isFavorite,
                onChanged: (value) => setState(() => _isFavorite = value),
              ),
            ),
            const SizedBox(height: 30),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isEditing
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                    ),
              label: Text(
                _saving
                    ? 'Saving...'
                    : _isEditing
                        ? 'Save changes'
                        : 'Save contact',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your contact details are stored securely on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8A90A1),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF454B60),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF252A3D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF858B9D),
          ),
        ),
      ],
    );
  }
}
