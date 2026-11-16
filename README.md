# Codex Account Hub for Windows

Codex Account Hub is a portable Windows PowerShell 5.1 + Windows Forms utility for managing a user's own local Codex authentication files. It supports importing, migrating, backing up, viewing and switching between up to five local account records.

> Independent third-party project. It is not affiliated with or endorsed by OpenAI, Codex, CC Switch++ or any browser extension vendor.

## Features

- Import a user-selected `auth.json` and try to identify its email claims.
- Import the current user's `%USERPROFILE%\\.codex\\auth.json`.
- Migrate legacy `account1.json` and `account2.json` files.
- Remember the migration source path per Windows user.
- Keep account copies, an index, and backups under the current user's profile.
- Switch accounts with JSON validation, backups and temporary-file replacement.
- Copy the author's public contact email without opening a browser or mail client.
- Limit the local account list to five entries.

## Requirements

- Windows 10/11
- Windows PowerShell 5.1
- .NET Framework Windows Forms

## Run

1. Download or clone the repository.
2. Open `src/Codex-Account-Hub-Windows`.
3. Double-click `启动多账号管理器.vbs`.
4. Use `启动多账号管理器（控制台备用）.bat` if the VBS launcher is blocked by local policy.

The application stores runtime data in the current Windows user's profile, not in the application folder:

```text
%USERPROFILE%\\Documents\\CodexAccounts\\
%LOCALAPPDATA%\\CodexAccountHub\\settings.json
%USERPROFILE%\\.codex\\auth.json
```

`auth.json` is a sensitive authentication credential. Never commit it, upload it, or share the runtime `CodexAccounts` directory.

## Testing

The `tests/fixtures` folder contains fake JSON files using the reserved `.invalid` domain. They contain no real credentials. Use them only in a separate Windows test account or an isolated test environment.

The v0.2.9 release was checked with:

- PowerShell parser validation;
- clean ZIP inventory and sensitive-file scanning;
- a separate Windows test user;
- fake JSON import, migration, restart, five-account limit, deletion and switching checks;
- copy-email behavior verification.

## Privacy and security boundary

This tool is local-only by design. It does not provide account registration, cloud sync, telemetry, automatic updates or account upload. The tutorial button can open a user-requested Bilibili search page; third-party site behavior is outside this project.

The public author contact is `wozhixiangxinni@foxmail.com`. This address is intentionally included in the UI and documentation. It is not a user credential.

See [`docs/隐私与安全说明.txt`](docs/隐私与安全说明.txt), [`docs/免责声明.txt`](docs/免责声明.txt) and [`SECURITY.md`](SECURITY.md).

## Release

The portable ZIP is distributed through GitHub Releases. Release assets should contain only the application files and documentation. Never attach a user's `auth.json`, runtime account directory, or personal test data.

## License

No open-source license has been selected yet. Until a license is added, publication does not grant permission to reuse or redistribute the source beyond the rights provided by applicable law.
