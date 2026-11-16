# Codex Account Hub for Windows

# Windows 版 Codex 多账号管理工具

Codex Account Hub is a portable Windows PowerShell 5.1 + Windows Forms
utility for managing a user's own local Codex authentication files. It
supports importing, migrating, backing up, viewing and switching between
up to five local account records.

Codex Account Hub 是一款基于 Windows PowerShell 5.1 和 Windows Forms
开发的便携式 Windows 工具，用于管理用户自己的本地 Codex
身份验证文件。支持导入、迁移、备份、查看和切换最多五个本地账号记录。

> Independent third-party project. It is not affiliated with or endorsed
> by OpenAI, Codex, CC Switch++ or any browser extension vendor.

> 本项目为独立第三方项目，与 OpenAI、Codex、CC Switch++
> 或任何浏览器扩展开发商均无隶属、合作或官方认可关系。

------------------------------------------------------------------------

## Features / 功能特点

-   Import a user-selected `auth.json` and try to identify its email
    claims.\
    导入用户自行选择的 `auth.json` 文件，并尝试识别其中的邮箱信息。
-   Import the current user's `%USERPROFILE%\\.codex\\auth.json`.\
    导入当前 Windows 用户目录下的 `%USERPROFILE%\\.codex\\auth.json`
    文件。
-   Migrate legacy `account1.json` and `account2.json` files.\
    支持迁移旧版本的 `account1.json` 和 `account2.json` 文件。
-   Remember the migration source path per Windows user.\
    按 Windows 用户分别记住迁移来源路径。
-   Keep account copies, an index, and backups under the current user's
    profile.\
    将账号副本、索引文件和备份保存在当前 Windows 用户的个人目录中。
-   Switch accounts with JSON validation, backups and temporary-file
    replacement.\
    切换账号时执行 JSON 格式验证，并使用备份和临时文件替换机制保护数据。
-   Copy the author's public contact email without opening a browser or
    mail client.\
    支持一键复制作者公开联系邮箱，无需打开浏览器或邮件客户端。
-   Limit the local account list to five entries.\
    本地账号列表最多支持五个账号。

------------------------------------------------------------------------

## Requirements / 运行环境

-   Windows 10/11
-   Windows PowerShell 5.1
-   .NET Framework Windows Forms

运行要求：

-   Windows 10/11 操作系统
-   Windows PowerShell 5.1
-   .NET Framework Windows Forms 组件

------------------------------------------------------------------------

## Run / 启动方式

1.  Download or clone the repository.
2.  Open `src/Codex-Account-Hub-Windows`.
3.  Double-click `启动多账号管理器.vbs`.
4.  Use `启动多账号管理器（控制台备用）.bat` if the VBS launcher is
    blocked by local policy.

启动步骤：

1.  下载或克隆本项目仓库。
2.  打开 `src/Codex-Account-Hub-Windows` 目录。
3.  双击运行 `启动多账号管理器.vbs`。
4.  如果 VBS 启动器受到本地系统策略限制，可以使用
    `启动多账号管理器（控制台备用）.bat` 作为备用启动方式。

The application stores runtime data in the current Windows user's
profile, not in the application folder:

程序运行数据保存在当前 Windows 用户的个人目录中，而不是软件安装目录：

``` text
%USERPROFILE%\\Documents\\CodexAccounts\\
%LOCALAPPDATA%\\CodexAccountHub\\settings.json
%USERPROFILE%\\.codex\\auth.json
```

`auth.json` is a sensitive authentication credential. Never commit it,
upload it, or share the runtime `CodexAccounts` directory.

`auth.json` 属于敏感身份验证凭证。请勿将其提交到
GitHub、上传到网络或分享运行时使用的 `CodexAccounts` 目录。

------------------------------------------------------------------------

## Testing / 测试说明

The `tests/fixtures` folder contains fake JSON files using the reserved
`.invalid` domain. They contain no real credentials. Use them only in a
separate Windows test account or an isolated test environment.

`tests/fixtures` 文件夹包含使用保留的 `.invalid` 域名制作的模拟 JSON
文件。这些文件不包含真实身份验证凭证。请仅在独立的 Windows
测试账号或隔离测试环境中使用。

The v0.2.9 release was checked with:

v0.2.9 版本已完成以下检查：

-   PowerShell parser validation;\
    PowerShell 脚本语法解析验证；
-   clean ZIP inventory and sensitive-file scanning;\
    ZIP 发布包文件清单检查及敏感文件扫描；
-   a separate Windows test user;\
    使用独立 Windows 测试用户进行测试；
-   fake JSON import, migration, restart, five-account limit, deletion
    and switching checks;\
    使用模拟 JSON
    文件测试导入、迁移、重启、五账号数量限制、删除及账号切换；
-   copy-email behavior verification.\
    邮箱复制功能验证。

------------------------------------------------------------------------

## Privacy and security boundary / 隐私与安全说明

This tool is local-only by design. It does not provide account
registration, cloud sync, telemetry, automatic updates or account
upload. The tutorial button can open a user-requested Bilibili search
page; third-party site behavior is outside this project.

本工具从设计上采用纯本地运行方式，不提供账号注册、云同步、遥测数据收集、自动更新或账号上传功能。教程按钮可以根据用户主动操作打开
Bilibili 搜索页面；第三方网站的行为不属于本项目的控制范围。

The public author contact is `wozhixiangxinni@foxmail.com`. This address
is intentionally included in the UI and documentation. It is not a user
credential.

作者公开联系邮箱为
`wozhixiangxinni@foxmail.com`。该邮箱是有意展示在软件界面和项目文档中的公开联系方式，不属于用户身份验证凭证。

See [`docs/隐私与安全说明.txt`](docs/隐私与安全说明.txt),
[`docs/免责声明.txt`](docs/免责声明.txt) and
[`SECURITY.md`](SECURITY.md).

更多信息请参阅：

-   [`docs/隐私与安全说明.txt`](docs/隐私与安全说明.txt)
-   [`docs/免责声明.txt`](docs/免责声明.txt)
-   [`SECURITY.md`](SECURITY.md)

------------------------------------------------------------------------

## Release / 版本发布

The portable ZIP is distributed through GitHub Releases. Release assets
should contain only the application files and documentation. Never
attach a user's `auth.json`, runtime account directory, or personal test
data.

本项目通过 GitHub Releases 发布便携式 ZIP
压缩包。发布附件应仅包含软件文件和项目文档。严禁在发布包中包含用户的
`auth.json`、运行时账号目录或个人测试数据。

------------------------------------------------------------------------

## License / 开源许可

No open-source license has been selected yet. Until a license is added,
publication does not grant permission to reuse or redistribute the
source beyond the rights provided by applicable law.

目前本项目尚未选择开源许可证。在正式添加许可证之前，项目的公开发布并不代表任何人自动获得超出适用法律规定范围的源代码使用或再分发权限。
