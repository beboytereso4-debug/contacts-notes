# Contacts Book

A Flutter contacts manager with local SQLite storage.

## Features

- Create, view, update, and delete contacts
- Search by name, phone number, or email
- Mark contacts as favorites
- Filter the list to show all contacts or favorites
- Swipe a contact left to delete it, with confirmation and undo
- Store contact information locally with SQLite

## UI/UX improvements

This contribution refreshes the existing Material 3 interface with a consistent indigo color palette, clearer typography, rounded search and form fields, contact summary cards, improved contact list cards, initials avatars, favorites filters, and helpful empty states.

The existing SQLite data model and CRUD flow are retained.

## Run locally

1. Install Flutter and set up an Android emulator or connect an Android device.
2. Open this project folder in VS Code or Android Studio.
3. Run:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```

## Pull request

Suggested PR title:

`Enhance Contacts Book UI/UX with a modern Material 3 design`

Suggested summary:

- Refresh the app theme and visual styling.
- Improve the contacts overview with total and favorite counts.
- Add All Contacts and Favorites filters.
- Redesign contact cards, search, form fields, and empty states.
- Improve delete confirmation and feedback while preserving SQLite CRUD behavior.
