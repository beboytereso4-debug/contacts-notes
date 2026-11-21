import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../main.dart';
import '../models/contact.dart';
import 'contact_form_screen.dart';
import 'contact_profile_screen.dart';

enum _ContactFilter { all, favorites }

enum _ContactSort { nameAsc, nameDesc, newest, oldest }

extension on _ContactSort {
  String get label {
    switch (this) {
      case _ContactSort.nameAsc:
        return 'Name (A–Z)';
      case _ContactSort.nameDesc:
        return 'Name (Z–A)';
      case _ContactSort.newest:
        return 'Date added (newest)';
      case _ContactSort.oldest:
        return 'Date added (oldest)';
    }
  }

  IconData get icon => switch (this) {
        _ContactSort.nameAsc ||
        _ContactSort.nameDesc =>
          Icons.sort_by_alpha_rounded,
        _ContactSort.newest => Icons.arrow_downward_rounded,
        _ContactSort.oldest => Icons.arrow_upward_rounded,
      };
}

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
  _ContactFilter _filter = _ContactFilter.all;
  _ContactSort _sort = _ContactSort.nameAsc;

  int get _favoriteCount =>
      _contacts.where((contact) => contact.isFavorite).length;

  List<Contact> get _visibleContacts {
    if (_filter == _ContactFilter.favorites) {
      return _contacts.where((contact) => contact.isFavorite).toList();
    }
    return _contacts;
  }

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
    final contacts = await _db.getContacts(
      query: _searchController.text,
      sortBy: (_sort == _ContactSort.newest || _sort == _ContactSort.oldest)
          ? 'date'
          : 'name',
      descending:
          _sort == _ContactSort.nameDesc || _sort == _ContactSort.newest,
    );
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

  Future<void> _openProfile(Contact contact) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: contact)),
    );
    if (changed == true) _loadContacts();
  }

  Future<void> _toggleFavorite(Contact contact) async {
    await _db.update(contact.copyWith(isFavorite: !contact.isFavorite));
    await _loadContacts();
  }

  Future<void> _delete(Contact contact) async {
    await _db.delete(contact.id!);
    if (!mounted) return;
    setState(() => _contacts.removeWhere((item) => item.id == contact.id));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${contact.name} was deleted'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await _db.insert(contact.copyWith(id: null));
              _loadContacts();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final visibleContacts = _visibleContacts;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurface =
        isDark ? colorScheme.surfaceContainerHigh : Colors.white;
    final borderColor =
        isDark ? colorScheme.outlineVariant : const Color(0xFFE7E9F1);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contacts Book',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ContactsBookApp.themeModeNotifier,
            builder: (context, mode, _) {
              final darkModeActive = mode == ThemeMode.dark;
              return IconButton(
                tooltip: darkModeActive
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                onPressed: ContactsBookApp.toggleTheme,
                icon: Icon(
                  darkModeActive
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh contacts',
            onPressed: _loadContacts,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add contact'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    sliver: SliverToBoxAdapter(
                      child: _buildOverview(),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: SearchBar(
                        controller: _searchController,
                        hintText: 'Search name, phone or email',
                        leading: const Icon(Icons.search_rounded),
                        elevation: const WidgetStatePropertyAll(0),
                        backgroundColor: WidgetStatePropertyAll(cardSurface),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 16),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: borderColor),
                          ),
                        ),
                        onChanged: (_) => _loadContacts(),
                        trailing: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _loadContacts();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          _filterChip(
                            label: 'All contacts',
                            selected: _filter == _ContactFilter.all,
                            onTap: () => setState(
                              () => _filter = _ContactFilter.all,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _filterChip(
                            label: 'Favorites',
                            selected: _filter == _ContactFilter.favorites,
                            icon: Icons.star_rounded,
                            onTap: () => setState(
                              () => _filter = _ContactFilter.favorites,
                            ),
                          ),
                          const Spacer(),
                          PopupMenuButton<_ContactSort>(
                            tooltip: 'Sort contacts',
                            initialValue: _sort,
                            onSelected: (value) {
                              setState(() => _sort = value);
                              _loadContacts();
                            },
                            itemBuilder: (context) => _ContactSort.values
                                .map((sort) => PopupMenuItem<_ContactSort>(
                                      value: sort,
                                      child: Row(
                                        children: [
                                          Icon(sort.icon, size: 18),
                                          const SizedBox(width: 10),
                                          Text(sort.label),
                                          if (_sort == sort) ...[
                                            const SizedBox(width: 8),
                                            const Icon(Icons.check_rounded,
                                                size: 18),
                                          ],
                                        ],
                                      ),
                                    ))
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: cardSurface,
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sort_rounded, size: 17),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Sort',
                                    style:
                                        Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${visibleContacts.length} ${visibleContacts.length == 1 ? 'contact' : 'contacts'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visibleContacts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList.separated(
                        itemCount: visibleContacts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final contact = visibleContacts[index];
                          return _buildContactCard(contact);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stay connected.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Keep the people who matter close.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.people_alt_rounded,
                label: 'Total contacts',
                value: '${_contacts.length}',
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.star_rounded,
                label: 'Favorites',
                value: '$_favoriteCount',
                color: const Color(0xFFE4A52D),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colorScheme.outlineVariant
              : const Color(0xFFEDEFF5).withValues(alpha: .9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg =
        isDark ? colorScheme.surfaceContainerHigh : Colors.white;
    final unselectedBorder =
        isDark ? colorScheme.outlineVariant : const Color(0xFFE7E9F1);

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 5),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 16,
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
      label: Text(label),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      selectedColor: colorScheme.primary,
      backgroundColor: unselectedBg,
      side: BorderSide(
        color: selected ? colorScheme.primary : unselectedBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }

  Widget _buildContactCard(Contact contact) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = contact.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    final hasPhoto = contact.photoPath != null &&
        contact.photoPath!.isNotEmpty &&
        File(contact.photoPath!).existsSync();

    return Dismissible(
      key: ValueKey(contact.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFD94B4B),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Delete contact?'),
                content: Text('Remove ${contact.name} from your contacts?'),
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
            ) ??
            false;
      },
      onDismissed: (_) => _delete(contact),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openProfile(contact),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: colorScheme.secondaryContainer,
                  backgroundImage:
                      hasPhoto ? FileImage(File(contact.photoPath!)) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          initials.isEmpty ? '?' : initials,
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              contact.phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (contact.email.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.mail_outline_rounded,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                contact.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: contact.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: () => _toggleFavorite(contact),
                  icon: Icon(
                    contact.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: contact.isFavorite
                        ? const Color(0xFFE4A52D)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSearching = _searchController.text.trim().isNotEmpty;
    final isFavorites = _filter == _ContactFilter.favorites;

    final title = isSearching
        ? 'No matches found'
        : isFavorites
            ? 'No favorite contacts yet'
            : 'Your contacts start here';

    final message = isSearching
        ? 'Try another name, phone number or email.'
        : isFavorites
            ? 'Tap the star on a contact to save it here.'
            : 'Add your first contact to keep important details in one place.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.people_outline,
                size: 36,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!isSearching && !isFavorites) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add your first contact'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
