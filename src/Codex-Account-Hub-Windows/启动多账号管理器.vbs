Option Explicit
Dim shell, fso, scriptPath, powershellPath, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptPath = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Codex-Multi-Account-Manager.ps1")
powershellPath = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
If Not fso.FileExists(scriptPath) Then
  MsgBox "Cannot find Codex-Multi-Account-Manager.ps1 in this folder.", vbCritical, "Codex Account Hub"
  WScript.Quit 1
End If
If Not fso.FileExists(powershellPath) Then
  MsgBox "Windows PowerShell 5.1 was not found.", vbCritical, "Codex Account Hub"
  WScript.Quit 1
End If
command = Chr(34) & powershellPath & Chr(34) & " -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File " & Chr(34) & scriptPath & Chr(34)
shell.Run command, 0, False
