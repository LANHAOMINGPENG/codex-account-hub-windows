#requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = "Stop"
$BaseDir = Join-Path $env:USERPROFILE "Documents\CodexAccounts"
$AccountsDir = Join-Path $BaseDir "Accounts"
$BackupDir = Join-Path $BaseDir "Backups"
$Manifest = Join-Path $BaseDir "accounts-index.json"
$MigrationSourceFile = Join-Path $BaseDir "migration-source.txt"
$SettingsDir = Join-Path $env:LOCALAPPDATA "CodexAccountHub"
$SettingsFile = Join-Path $SettingsDir "settings.json"
$MaxAccounts = 5
$ActiveAuth = Join-Path (Join-Path $env:USERPROFILE ".codex") "auth.json"
$AuthorEmail = "wozhixiangxinni@foxmail.com"

New-Item -ItemType Directory -Force -Path $BaseDir,$AccountsDir,$BackupDir | Out-Null

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "找不到文件：$Path" }
    $raw = [IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "文件为空：$Path" }
    try { return (ConvertFrom-Json -InputObject $raw -ErrorAction Stop) }
    catch { throw "不是有效的 JSON 文件。" }
}
function Decode-JwtPayload([string]$Token) {
    $p = $Token.Split('.')
    if ($p.Count -lt 2) { return $null }
    $s = $p[1].Replace('-','+').Replace('_','/')
    switch ($s.Length % 4) { 2 {$s+='=='} 3 {$s+='='} }
    try { return (ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s))) -ErrorAction Stop) } catch { return $null }
}
function Find-Identity($Obj) {
    # Read common email claims directly and from JWT payloads.
    # Do not print or persist token contents.
    $emails = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $tokens = New-Object 'System.Collections.Generic.List[string]'
    $emailKeys = @('email','preferred_username','upn','unique_name','user_email','userEmail','mail')

    function Walk($x) {
        if ($null -eq $x) { return }
        if ($x -is [System.Collections.IDictionary]) {
            foreach ($k in $x.Keys) {
                $v = $x[$k]
                if (($emailKeys -contains [string]$k) -and ($v -is [string]) -and ($v.Trim() -match '^[^@\s]+@[^@\s]+\.[^@\s]+$')) {
                    [void]$emails.Add($v.Trim().ToLowerInvariant())
                }
                if ($v -is [string] -and $v -match '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$') {
                    $tokens.Add($v)
                }
                Walk $v
            }
        } elseif ($x -is [pscustomobject]) {
            foreach ($prop in $x.PSObject.Properties) {
                $v = $prop.Value
                if (($emailKeys -contains [string]$prop.Name) -and ($v -is [string]) -and ($v.Trim() -match '^[^@\s]+@[^@\s]+\.[^@\s]+$')) {
                    [void]$emails.Add($v.Trim().ToLowerInvariant())
                }
                if ($v -is [string] -and $v -match '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$') {
                    $tokens.Add($v)
                }
                Walk $v
            }
        } elseif ($x -is [System.Array]) {
            foreach ($v in $x) { Walk $v }
        }
    }

    Walk $Obj
    # Decode JWT payloads found in auth.json (commonly id_token/access_token).
    # Repeat a bounded number of passes in case claims contain nested objects.
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($pass = 0; $pass -lt 2; $pass++) {
        $batch = @($tokens | Where-Object { $seen.Add($_) })
        if ($batch.Count -eq 0) { break }
        foreach ($t in $batch) {
            $payload = Decode-JwtPayload $t
            if ($payload) { Walk $payload }
        }
    }

    $arr = @($emails | ForEach-Object { $_ })
    if ($arr.Count -eq 1) { return $arr[0] }
    # If the file contains multiple different email claims, do not guess.
    return $null
}
function Load-Accounts {
    if (-not (Test-Path -LiteralPath $Manifest)) { return @() }
    try {
        $data = Read-JsonFile $Manifest
        # Accept the array format used by the earlier build and the wrapped format used now.
        if ($data -is [System.Array]) { return @($data) }
        if ($null -ne $data.accounts) { return @($data.accounts) }
        if ($data.name -and $data.file) { return @($data) }
    } catch {}
    return @()
}
function Save-Accounts {
    New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null
    if (Test-Path -LiteralPath $Manifest -PathType Leaf) {
        try { Backup-File $Manifest "accounts-index-before-update" | Out-Null } catch {}
    }
    $payload = [pscustomobject]@{
        schemaVersion = 1
        updatedAt = (Get-Date).ToString("s")
        accounts = @($script:Accounts)
    }
    $json = ConvertTo-Json -InputObject $payload -Depth 8
    $temp = $Manifest + ".tmp-" + [guid]::NewGuid().ToString("N")
    try {
        [IO.File]::WriteAllText($temp, $json, [Text.Encoding]::UTF8)
        $null = Read-JsonFile $temp
        if (Test-Path -LiteralPath $Manifest -PathType Leaf) {
            Replace-FileSafely $temp $Manifest
        } else {
            [IO.File]::Move($temp, $Manifest)
        }
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}
function Safe-FileName([string]$Name) {
    $n=[regex]::Replace($Name,'[\\/:*?"<>|]','_').Trim()
    if([string]::IsNullOrWhiteSpace($n)){ $n="account" }
    return $n
}
function Backup-File([string]$Path,[string]$Prefix) {
    if(Test-Path -LiteralPath $Path -PathType Leaf) {
        $stamp=Get-Date -Format "yyyyMMdd-HHmmss-fff"
        $dest=Join-Path $BackupDir ($Prefix+"-"+$stamp+".json")
        Copy-Item -LiteralPath $Path -Destination $dest
        return $dest
    }
    return $null
}
function Replace-FileSafely([string]$Source,[string]$Destination) {
    # Windows PowerShell/.NET Framework does not accept a null backup path for File.Replace.
    # Use a temporary backup path, then remove it after the atomic replacement succeeds.
    $replaceBackup = $Destination + ".replace-backup-" + [guid]::NewGuid().ToString("N") + ".tmp"
    try {
        [IO.File]::Replace($Source,$Destination,$replaceBackup)
    } finally {
        if(Test-Path -LiteralPath $replaceBackup){Remove-Item -LiteralPath $replaceBackup -Force -ErrorAction SilentlyContinue}
    }
}
function Add-AccountFromFile([string]$Name,[string]$Path,[bool]$Replace=$false) {
    $obj=Read-JsonFile $Path
    $email=Find-Identity $obj
    $safe=Safe-FileName $Name
    $existing=@($script:Accounts | Where-Object { $_.name -eq $Name -or ($email -and $_.email -and $_.email -eq $email) })
    if($existing.Count -gt 0 -and -not $Replace) { throw "这个名称或邮箱已经存在。请检查账号列表，避免重复导入。" }
    if($existing.Count -eq 0 -and $script:Accounts.Count -ge $MaxAccounts) { throw "已达到最多 $MaxAccounts 个账号的上限。请先删除不再使用的账号记录，再导入新账号。" }
    # Use an opaque local filename so different display names cannot collide after sanitization.
    $dest=Join-Path $AccountsDir ("account-"+[guid]::NewGuid().ToString("N")+".json")
    Copy-Item -LiteralPath $Path -Destination $dest
    $entry=[pscustomobject]@{ name=$Name; email=$email; file=$dest; imported=(Get-Date).ToString("s") }
    if($existing.Count -gt 0) {
        $script:Accounts=@($script:Accounts | Where-Object { $_.name -ne $Name -and (-not $email -or $_.email -ne $email) })
    }
    $script:Accounts=@($script:Accounts)+$entry
    Save-Accounts
    return $entry
}
function Refresh-List {
    $list.Items.Clear()
    $currentEmail = $null
    if (Test-Path -LiteralPath $ActiveAuth) {
        try { $currentEmail = Find-Identity (Read-JsonFile $ActiveAuth) } catch {}
    }

    $metadataChanged = $false
    foreach ($a in $script:Accounts) {
        $detectedEmail = $null
        $fileReadable = $false
        if ($a.file -and (Test-Path -LiteralPath $a.file -PathType Leaf)) {
            try {
                $accountObj = Read-JsonFile $a.file
                $fileReadable = $true
                $detectedEmail = Find-Identity $accountObj
            } catch {}
        }

        # Repair older index entries that stored no email by re-reading their local auth file.
        if ($detectedEmail -and ([string]$a.email -ne [string]$detectedEmail)) {
            $a.email = $detectedEmail
            $metadataChanged = $true
        }

        $emailText = if ($detectedEmail) { $detectedEmail } elseif ($a.email) { [string]$a.email } elseif ($fileReadable) { "文件有效，未发现可识别邮箱" } else { "账号文件不可读/不存在" }
        $item = New-Object Windows.Forms.ListViewItem([string]$a.name)
        [void]$item.SubItems.Add([string]$emailText)
        $status = if ($currentEmail -and $a.email -and $currentEmail -eq $a.email) { "当前使用" } else { "已保存" }
        [void]$item.SubItems.Add($status)
        $item.Tag = $a
        [void]$list.Items.Add($item)
    }

    if ($metadataChanged) { Save-Accounts }
    $currentLabel.Text = if ($currentEmail) { "当前 Codex 账号：$currentEmail" } else { "当前 Codex 账号：无法自动识别（不影响手动切换）" }
}
function Show-Error([string]$Message) {
    [void][Windows.Forms.MessageBox]::Show($Message,"Codex 多账号管理器",[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Warning)
}
function Copy-AuthorEmail {
    try {
        [Windows.Forms.Clipboard]::SetText($AuthorEmail)
        [void][Windows.Forms.MessageBox]::Show("已复制作者邮箱：$AuthorEmail","复制成功",[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        Show-Error "复制失败，请手动复制邮箱：$AuthorEmail"
    }
}
function Get-SavedMigrationPath {
    # New setting location is per-Windows-user and persists across app-folder updates.
    if (Test-Path -LiteralPath $SettingsFile -PathType Leaf) {
        try {
            $settings = Read-JsonFile $SettingsFile
            if ($settings.migrationSourcePath -and (Test-Path -LiteralPath ([string]$settings.migrationSourcePath) -PathType Container)) {
                return [string]$settings.migrationSourcePath
            }
        } catch {}
    }
    # Backward compatibility: read the path saved by 0.2.4.
    if (Test-Path -LiteralPath $MigrationSourceFile -PathType Leaf) {
        try {
            $oldPath = [IO.File]::ReadAllText($MigrationSourceFile).Trim()
            if ($oldPath -and (Test-Path -LiteralPath $oldPath -PathType Container)) { return $oldPath }
        } catch {}
    }
    return $null
}
function Save-MigrationPath([string]$Path) {
    New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null
    $settings = [pscustomobject]@{ migrationSourcePath = $Path; updatedAt = (Get-Date).ToString("s") }
    $json = ConvertTo-Json -InputObject $settings -Depth 4
    [IO.File]::WriteAllText($SettingsFile, $json, [Text.Encoding]::UTF8)
    # Keep the previous setting file in sync for compatibility with the prior build.
    try { [IO.File]::WriteAllText($MigrationSourceFile, $Path, [Text.Encoding]::UTF8) } catch {}
}
function Select-MigrationFolder([string]$InitialPath) {
    $folder = New-Object Windows.Forms.FolderBrowserDialog
    $folder.Description = "请选择旧版双账号工具中 account1.json 和 account2.json 所在的文件夹。必须选择直接包含这两个文件的那一层文件夹。"
    $folder.ShowNewFolderButton = $false
    if ($InitialPath -and (Test-Path -LiteralPath $InitialPath -PathType Container)) { $folder.SelectedPath = $InitialPath }
    if ($folder.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) { return $folder.SelectedPath }
    return $null
}
function Import-OldAccounts {
    $savedPath = Get-SavedMigrationPath
    $documentsPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    $defaultPath = Join-Path $documentsPath "CodexAccounts"
    $sourceDir = $null

    if ($savedPath) {
        $choice = [Windows.Forms.MessageBox]::Show(
            "已记住旧账号文件夹：`r`n$savedPath`r`n`r`n是：直接使用此路径`r`n否：重新选择/更改路径`r`n取消：退出",
            "旧账号迁移路径",
            [Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [Windows.Forms.MessageBoxIcon]::Question
        )
        if ($choice -eq [Windows.Forms.DialogResult]::Cancel) { return }
        if ($choice -eq [Windows.Forms.DialogResult]::Yes) { $sourceDir = $savedPath }
        else { $sourceDir = Select-MigrationFolder $savedPath }
    } else {
        $hasDefaultFiles = (Test-Path -LiteralPath (Join-Path $defaultPath "account1.json")) -or (Test-Path -LiteralPath (Join-Path $defaultPath "account2.json"))
        if ($hasDefaultFiles) {
            $sourceDir = $defaultPath
        } else {
            $sourceDir = Select-MigrationFolder $defaultPath
        }
    }
    if (-not $sourceDir) { return }

    $file1 = Join-Path $sourceDir "account1.json"
    $file2 = Join-Path $sourceDir "account2.json"
    if (-not (Test-Path -LiteralPath $file1 -PathType Leaf) -and -not (Test-Path -LiteralPath $file2 -PathType Leaf)) {
        $newPath = Select-MigrationFolder $sourceDir
        if (-not $newPath) { return }
        $sourceDir = $newPath
        $file1 = Join-Path $sourceDir "account1.json"
        $file2 = Join-Path $sourceDir "account2.json"
    }

    try { Save-MigrationPath $sourceDir } catch {
        Show-Error "无法保存迁移路径设置：$($_.Exception.Message)"
        return
    }

    $added = 0
    $notes = New-Object 'System.Collections.Generic.List[string]'
    $found = 0
    foreach ($pair in @(@{path=$file1;name="账号1"}, @{path=$file2;name="账号2"})) {
        if (Test-Path -LiteralPath $pair.path -PathType Leaf) {
            $found++
            try {
                $obj = Read-JsonFile $pair.path
                $email = Find-Identity $obj
                $dupe = @($script:Accounts | Where-Object {
                    $_.name -eq $pair.name -or ($email -and $_.email -and $_.email -eq $email)
                })
                if ($dupe.Count -eq 0) {
                    $null = Add-AccountFromFile $pair.name $pair.path $false
                    $added++
                } else {
                    $notes.Add("$($pair.name)：名称或邮箱已存在，跳过")
                }
            } catch {
                $notes.Add("$($pair.name)：迁移失败 - $($_.Exception.Message)")
            }
        }
    }

    if ($found -eq 0) {
        [void][Windows.Forms.MessageBox]::Show(
            "所选文件夹中没有找到 account1.json 或 account2.json。`r`n`r`n请确认文件名完全一致，并选择直接包含文件的文件夹。`r`n`r`n路径设置不会被清除。",
            "未找到旧账号文件",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }

    Refresh-List
    $msg = "旧账号迁移完成。`r`n来源文件夹：$sourceDir`r`n新增账号：$added / 最多 $MaxAccounts 个账号"
    if ($notes.Count) { $msg += "`r`n" + ($notes -join "`r`n") }
    $msg += "`r`n`r`n原始文件不会被移动或删除。`r`n下次可直接使用已记住路径，也可选择更改路径。"
    [void][Windows.Forms.MessageBox]::Show($msg, "迁移旧账号", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information)
}
function Import-CurrentAccount {
    if(-not (Test-Path -LiteralPath $ActiveAuth -PathType Leaf)) {
        Show-Error "没有找到当前 Codex 的 auth.json：$ActiveAuth"
        return
    }
    try {
        $obj=Read-JsonFile $ActiveAuth
        $email=Find-Identity $obj
        if($email -and @($script:Accounts | Where-Object {$_.email -and $_.email -eq $email}).Count -gt 0) {
            Show-Error "这个邮箱已经在账号列表中，无需重复导入。"
            return
        }
        $defaultName=if($email){$email.Split("@")[0]}else{"当前账号"}
        $name=[Microsoft.VisualBasic.Interaction]::InputBox("将当前 Codex 登录保存为一个独立账号。请输入名称：","导入当前账号",$defaultName)
        if([string]::IsNullOrWhiteSpace($name)){return}
        $entry=Add-AccountFromFile $name $ActiveAuth $false
        Refresh-List
        $msg="已保存当前账号：$($entry.name)"
        if($entry.email){$msg+="`r`n识别邮箱：$($entry.email)"}
        [void][Windows.Forms.MessageBox]::Show($msg,"导入成功",[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
    } catch { Show-Error $_.Exception.Message }
}

$script:Accounts=Load-Accounts
$form=New-Object Windows.Forms.Form
$form.Text="Codex 多账号管理器"
$form.Size=New-Object Drawing.Size(900,625)
$form.StartPosition="CenterScreen"
$form.MinimumSize=New-Object Drawing.Size(820,570)
$form.Font=New-Object Drawing.Font("Microsoft YaHei UI",9)
$form.BackColor=[Drawing.Color]::White

$header=New-Object Windows.Forms.Label
$header.Text="Codex 多账号管理器"
$header.Font=New-Object Drawing.Font("Microsoft YaHei UI",18,[Drawing.FontStyle]::Bold)
$header.Location=New-Object Drawing.Point(22,18);$header.Size=New-Object Drawing.Size(500,38)
$form.Controls.Add($header)

$sub=New-Object Windows.Forms.Label
$sub.Text="导入已有 auth.json · 最多管理 5 个账号 · 自动识别邮箱 · 一键切换"
$sub.ForeColor=[Drawing.Color]::DimGray
$sub.Location=New-Object Drawing.Point(24,58);$sub.Size=New-Object Drawing.Size(700,24)
$form.Controls.Add($sub)

$list=New-Object Windows.Forms.ListView
$list.Location=New-Object Drawing.Point(24,100);$list.Size=New-Object Drawing.Size(785,285)
$list.Anchor="Top,Bottom,Left,Right"
$list.View="Details";$list.FullRowSelect=$true;$list.GridLines=$true
[void]$list.Columns.Add("账号名称",180)
[void]$list.Columns.Add("识别邮箱",360)
[void]$list.Columns.Add("状态",150)
$form.Controls.Add($list)

$currentLabel=New-Object Windows.Forms.Label
$currentLabel.Location=New-Object Drawing.Point(26,395);$currentLabel.Size=New-Object Drawing.Size(780,24)
$currentLabel.Anchor="Bottom,Left";$currentLabel.ForeColor=[Drawing.Color]::DarkSlateBlue
$form.Controls.Add($currentLabel)

$btnImport=New-Object Windows.Forms.Button
$btnImport.Text="导入 auth.json"
$btnImport.Location=New-Object Drawing.Point(24,435);$btnImport.Size=New-Object Drawing.Size(130,36);$btnImport.Anchor="Bottom,Left"
$form.Controls.Add($btnImport)
$btnOld=New-Object Windows.Forms.Button
$btnOld.Text="迁移旧账号/设置路径"
$btnOld.Location=New-Object Drawing.Point(162,435);$btnOld.Size=New-Object Drawing.Size(130,36);$btnOld.Anchor="Bottom,Left"
$form.Controls.Add($btnOld)
$btnCurrent=New-Object Windows.Forms.Button
$btnCurrent.Text="导入当前账号"
$btnCurrent.Location=New-Object Drawing.Point(300,435);$btnCurrent.Size=New-Object Drawing.Size(130,36);$btnCurrent.Anchor="Bottom,Left"
$form.Controls.Add($btnCurrent)
$btnGuide=New-Object Windows.Forms.Button
$btnGuide.Text="导出教程"
$btnGuide.Location=New-Object Drawing.Point(438,435);$btnGuide.Size=New-Object Drawing.Size(105,36);$btnGuide.Anchor="Bottom,Left"
$form.Controls.Add($btnGuide)
$btnRefresh=New-Object Windows.Forms.Button
$btnRefresh.Text="刷新"
$btnRefresh.Location=New-Object Drawing.Point(551,435);$btnRefresh.Size=New-Object Drawing.Size(85,36);$btnRefresh.Anchor="Bottom,Left"
$form.Controls.Add($btnRefresh)
$btnContact=New-Object Windows.Forms.Button
$btnContact.Text="复制邮箱"
$btnContact.Location=New-Object Drawing.Point(647,435);$btnContact.Size=New-Object Drawing.Size(105,36);$btnContact.Anchor="Bottom,Left"
$form.Controls.Add($btnContact)

$btnSwitch=New-Object Windows.Forms.Button
$btnSwitch.Text="切换到选中账号"
$btnSwitch.Location=New-Object Drawing.Point(24,480);$btnSwitch.Size=New-Object Drawing.Size(160,36);$btnSwitch.Anchor="Bottom,Left"
$btnSwitch.BackColor=[Drawing.Color]::FromArgb(225,245,230)
$form.Controls.Add($btnSwitch)
$btnRename=New-Object Windows.Forms.Button
$btnRename.Text="重命名"
$btnRename.Location=New-Object Drawing.Point(192,480);$btnRename.Size=New-Object Drawing.Size(100,36);$btnRename.Anchor="Bottom,Left"
$form.Controls.Add($btnRename)
$btnDelete=New-Object Windows.Forms.Button
$btnDelete.Text="删除记录"
$btnDelete.Location=New-Object Drawing.Point(300,480);$btnDelete.Size=New-Object Drawing.Size(100,36);$btnDelete.Anchor="Bottom,Left"
$form.Controls.Add($btnDelete)

$hint=New-Object Windows.Forms.Label
$hint.Text="最多保存 5 个账号。切换前请完全退出 Codex 和 VS Code；凭据仅保存在本机，请勿分享 auth.json。"
$hint.Location=New-Object Drawing.Point(26,530);$hint.Size=New-Object Drawing.Size(820,22);$hint.Anchor="Bottom,Left";$hint.ForeColor=[Drawing.Color]::DimGray
$form.Controls.Add($hint)

$guideLink=New-Object Windows.Forms.LinkLabel
$guideLink.Text="还没有 auth.json？点击查看导出步骤与视频搜索"
$guideLink.Location=New-Object Drawing.Point(26,555);$guideLink.Size=New-Object Drawing.Size(500,22);$guideLink.Anchor="Bottom,Left"
$form.Controls.Add($guideLink)

$contactLink=New-Object Windows.Forms.LinkLabel
$contactLink.Text="作者邮箱：$AuthorEmail（点击复制）"
$contactLink.Location=New-Object Drawing.Point(535,555);$contactLink.Size=New-Object Drawing.Size(320,22);$contactLink.Anchor="Bottom,Left"
$contactLink.LinkArea=New-Object Windows.Forms.LinkArea(0,$contactLink.Text.Length)
$form.Controls.Add($contactLink)

$btnImport.Add_Click({
    $name=[Microsoft.VisualBasic.Interaction]::InputBox("给这个账号起一个容易识别的名称，例如：工作号、个人号、备用号","导入账号","新账号")
    if([string]::IsNullOrWhiteSpace($name)){return}
    $dlg=New-Object Windows.Forms.OpenFileDialog
    $dlg.Title="选择 Codex 登录助手导出的 auth.json"
    $dlg.Filter="JSON 文件 (*.json)|*.json|所有文件 (*.*)|*.*"
    if($dlg.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){
        try {
            $entry=Add-AccountFromFile $name $dlg.FileName $false
            Refresh-List
            $msg="已导入：$($entry.name)"
            if($entry.email){$msg+="`r`n识别邮箱：$($entry.email)"}else{$msg+="`r`n文件内未发现可识别邮箱，但 JSON 格式有效。请在切换前核对账号身份。"}
            [void][Windows.Forms.MessageBox]::Show($msg,"导入成功",[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
        } catch { Show-Error $_.Exception.Message }
    }
})
$btnOld.Add_Click({ Import-OldAccounts })
$btnCurrent.Add_Click({ Import-CurrentAccount })
$btnGuide.Add_Click({ $guideLink.LinkVisited=$true; [void][Windows.Forms.MessageBox]::Show("操作步骤：`r`n1. 打开浏览器中的 Codex 登录助手扩展。`r`n2. 确认浏览器已登录你自己的 ChatGPT 账号。`r`n3. 在扩展中点击'导出身份信息'，保存 auth.json。`r`n4. 回到本软件，点击'导入 auth.json'并选择刚导出的文件。`r`n`r`n请只从你信任的扩展来源安装登录助手。auth.json 等同于敏感登录凭据，不要分享。","导出 auth.json 教程",[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information); Start-Process "https://search.bilibili.com/all?keyword=Codex%20auth.json%20%E5%AF%BC%E5%87%BA%20%E7%99%BB%E5%BD%95%E5%8A%A9%E6%89%8B" })
$guideLink.Add_LinkClicked({ param($sender,$e); $sender.LinkVisited=$true; Start-Process "https://search.bilibili.com/all?keyword=Codex%20auth.json%20%E5%AF%BC%E5%87%BA%20%E7%99%BB%E5%BD%95%E5%8A%A9%E6%89%8B" })
$btnRefresh.Add_Click({ Refresh-List })
$btnContact.Add_Click({ Copy-AuthorEmail })
$contactLink.Add_LinkClicked({ param($sender,$e); $sender.LinkVisited=$true; Copy-AuthorEmail })
$btnRename.Add_Click({
    if($list.SelectedItems.Count -eq 0){Show-Error "请先选择一个账号。";return}
    $a=$list.SelectedItems[0].Tag
    $new=[Microsoft.VisualBasic.Interaction]::InputBox("输入新的账号名称","重命名账号",$a.name)
    if([string]::IsNullOrWhiteSpace($new)){return}
    if(@($script:Accounts | Where-Object {$_.name -eq $new}).Count -gt 0){Show-Error "这个名称已存在。";return}
    $a.name=$new
    Save-Accounts;Refresh-List
})
$btnDelete.Add_Click({
    if($list.SelectedItems.Count -eq 0){Show-Error "请先选择一个账号。";return}
    $a=$list.SelectedItems[0].Tag
    $r=[Windows.Forms.MessageBox]::Show("只删除管理器中的账号记录和本地副本？`r`n原始导入文件不会删除。","确认删除",[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning)
    if($r -eq [Windows.Forms.DialogResult]::Yes){
        $script:Accounts=@($script:Accounts | Where-Object {$_.name -ne $a.name})
        # 保留账号文件作为安全备份，不自动物理删除
        Save-Accounts;Refresh-List
    }
})
$btnSwitch.Add_Click({
    if($list.SelectedItems.Count -eq 0){Show-Error "请先选择要切换到的账号。";return}
    $target=$list.SelectedItems[0].Tag
    if(-not (Test-Path -LiteralPath $target.file)){Show-Error "账号文件不存在。";return}
    $r=[Windows.Forms.MessageBox]::Show("即将切换到：$($target.name)`r`n邮箱：$(if($target.email){$target.email}else{'无法自动识别'})`r`n`r`n请确认 Codex、VS Code 已完全退出。继续吗？","确认切换",[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
    if($r -ne [Windows.Forms.DialogResult]::Yes){return}
    try {
        $targetObj=Read-JsonFile $target.file
        $targetEmail=Find-Identity $targetObj
        if($target.email -and $targetEmail -and $target.email -ne $targetEmail){throw "目标账号邮箱与保存记录不一致，已停止。"}
        if(Test-Path -LiteralPath $ActiveAuth){
            $activeObj=Read-JsonFile $ActiveAuth
            $activeEmail=Find-Identity $activeObj
            # 只有邮箱唯一匹配到已保存账号时，才自动更新当前账号备份
            $matches=@($script:Accounts | Where-Object {$activeEmail -and $_.email -and $_.email -eq $activeEmail})
            Backup-File $ActiveAuth "auth-before-switch" | Out-Null
            if($matches.Count -eq 1 -and $matches[0].file -ne $target.file){
                Backup-File $matches[0].file "account-before-refresh" | Out-Null
                Copy-Item -LiteralPath $ActiveAuth -Destination $matches[0].file -Force
            }
        }
        $codexDir=Split-Path $ActiveAuth -Parent
        New-Item -ItemType Directory -Force -Path $codexDir | Out-Null
        $temp=Join-Path $codexDir ("auth-switch-"+[guid]::NewGuid().ToString("N")+".tmp")
        try {
            Copy-Item -LiteralPath $target.file -Destination $temp
            $null=Read-JsonFile $temp
            if(Test-Path -LiteralPath $ActiveAuth -PathType Leaf) {
                Replace-FileSafely $temp $ActiveAuth
            } else {
                [IO.File]::Move($temp,$ActiveAuth)
            }
        } finally { if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force} }
        [void][Windows.Forms.MessageBox]::Show("已切换到 $($target.name)。`r`n请重新打开 Codex。","切换成功",[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
        Refresh-List
    } catch { Show-Error $_.Exception.Message }
})

Refresh-List
[void]$form.ShowDialog()
