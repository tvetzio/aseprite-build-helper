' Aseprite Personal Build Helper
' Helper author/maintainer: Etzio
' Project URL: https://github.com/tvetzio/aseprite-build-helper

Option Explicit

Dim shell, fso, helper, args
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

helper = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "aseprite_personal_build_helper.bat")

If Not fso.FileExists(helper) Then
  MsgBox "aseprite_personal_build_helper.bat was not found:" & vbCrLf & helper, vbCritical, "Aseprite Personal Build Helper"
  WScript.Quit 1
End If

args = """" & helper & """ --hidden"

' WindowStyle 0 = hidden.
' The BAT will automatically reopen itself visibly on first-time setup.
shell.Run args, 0, False
