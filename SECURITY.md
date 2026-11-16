# Security policy

## Do not submit credentials

Never open an issue, pull request or discussion containing:

- `auth.json`;
- access tokens or JWTs;
- `accounts-index.json`;
- files from `Documents\\CodexAccounts`;
- screenshots showing personal account data.

Use fake `.invalid` addresses for testing.

## Reporting a suspected leak

If a release or repository accidentally contains a credential or other private data, do not publish it further. Remove access to the affected credential first, then contact the maintainer privately at `wozhixiangxinni@foxmail.com` with the repository URL and file path. Do not attach the credential itself.

## Scope

This project is a local Windows utility. It does not provide server-side authentication, cloud storage or telemetry. Users remain responsible for protecting their local `CodexAccounts` directory and for checking whether their Windows Documents folder is backed up or synchronized by another service.
