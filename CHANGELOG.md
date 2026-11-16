# Changelog

## 0.2.9

- Fixed Windows PowerShell 5.1 `File.Replace` failures caused by passing a null backup path.
- Applied the safe replacement path to account-index updates and active-auth switching.
- Kept temporary-file validation and local backups.

## 0.2.8

- Changed the author contact action to copy the public email to the clipboard.
- Removed mail-client navigation from the contact action.

## 0.2.6

- Added per-user migration-path memory and compatibility with the legacy migration path file.
- Kept local-only account import, migration, backup and switching behavior.
