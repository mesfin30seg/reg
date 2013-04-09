#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=tbicon.ico
#AutoIt3Wrapper_Outfile=Install.exe
#AutoIt3Wrapper_Res_Comment=Contact imaging@us.panasonic.com for support.
#AutoIt3Wrapper_Res_Description=OneClick Panasonic Toughbook Installer.
#AutoIt3Wrapper_Res_Fileversion=1.2.1
#AutoIt3Wrapper_Res_LegalCopyright=Panasonic Corporation Of North America
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****
FileInstall("7za.exe", "C:\Windows\Temp\7za.exe", 1)
FileInstall("HideCmdWindowEvery3Sec.exe", "C:\Windows\Temp\HideCmdWindowEvery3Sec.exe", 1)
;** AUT2EXE settings
;================================================================================================================
; Panasonic Toughbook Parent Script
;  By Brian Gonzalez
;
; Purpose: Installs all drivers from "src\" subfolder using
;	the PInstall.bat scripts.
;================================================================================================================
; Changelog
;================================================================================================================
; 1.0 - Dec 12 2012
;	Added step to delete (pop) Optional Drivers from DriverZips Array.
; 1.1 - Dec 21 2012
;	Added PNPCheck function, corrected count of elements in driver array.
;	Added TASKKILL call at end of script to close CmdWindowEvery3Sec.exe
;	Updated .ICOs for both HideCmdWindowEvery3Sec.exe and install.exe
;	Also compiled code with PanaConsulting icon.
;	Cleaned up Progress Bar Display by adding Bundle Name and removing File Extension
; 1.2 - Jan 31 2013
;	Changed "##" o pre-fix used for skipped application/driver installs.
; 1.2.1 - Feb 4 2013
;	Changed script to dymanically search for Sub-Folder name and not reply on "src\" name.
;================================================================================================================
; AutoIt Includes
;================================================================================================================
#include <Date.au3>
#include <File.au3>
#include <Array.au3>
#include <GUIConstantsEx.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
;================================================================================================================
; Main Routine
;================================================================================================================
AutoItSetOption("MustDeclareVars", 0)
$sInstallVersion = "1.2.1"
Dim $aPNPIDContents[100] ;Array used when checking through the PNPID txt file

;If Not IsAdmin() Then ; Verifies user is Admin
;	MsgBox(0, "", "User is not an administrator.  Exiting script.")
;	Exit
;EndIf

; Create LogFile
$sLogFilePath = "C:\Windows\Temp"
$sLogFile = FileOpen($sLogFilePath & "\PanaInstall_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & ".log", 1)
If $sLogFile = -1 Then
	MsgBox(0, "Error", "Unable to access/create log file.")
	Exit
EndIf

; Tag LogFile with Start Date and Time
FileWriteLine($sLogFile, "Start Date/Time Stamp: " & _Now())

; Grab Sub-Folder path containing driver zip files
$cFoldersOnly = 2
$aSubFolders = _FileListToArray(@ScriptDir, "*", $cFoldersOnly)
$sSrcFolderName = $aSubFolders[1]
$sSrcPath = @ScriptDir & "\" & $aSubFolders[1]

; Add more information to the log file
FileWriteLine($sLogFile, "Beginning to Process Bundle Name: " & $sSrcFolderName)
FileWriteLine($sLogFile, "Script Version: " & $sInstallVersion)
FileWriteLine($sLogFile, "=========================================")

; Populate array with all zip files inside of "src" sub-folder
$sFilesOnly = 1
If FileExists($sSrcPath) Then
	$aDriverZips = _FileListToArray($sSrcPath, "*.zip", $sFilesOnly)
	;_ArrayDisplay($aDriverZips)
EndIf

; Start Looping program to hide Command Line Windows
;Check if .ZIPs array was populated, if not exit
If @error = 1 Then
	MsgBox(0, "", "No Driver Folders found in \ sub-folder. Exiting script.")
	Exit
EndIf

; Delete Optional Installs (##_) from DriverZips Array
_ArrayDelete($aDriverZips, 0) ;Delete Orig Array Count from Array
$sDriverZips = _ArrayToString($aDriverZips, ",")
$sTestQuery = '\Q##_\E.*?,'
$sDriverZipsNoOptionals = StringRegExpReplace($sDriverZips, $sTestQuery, "")
$aDriverZips = StringSplit($sDriverZipsNoOptionals, ",")

; Kick off Hide Command Shell Program
$sHideCmdWindowPath = "C:\Windows\Temp\HideCmdWindowEvery3Sec.exe"
If FileExists($sHideCmdWindowPath) Then
	Run($sHideCmdWindowPath, @ScriptDir, @SW_HIDE)
	FileWriteLine($sLogFile, "Kicked off " & $sHideCmdWindowPath & "):" & @error)
Else
	FileWriteLine($sLogFile, $sHideCmdWindowPath & " not found.")
EndIf

; Copy 7za.exe locally to process ZIP packages
$s7ZAPath = "C:\Windows\Temp\7za.exe"
; First Make Sure 7za.exe Exists.
If Not (FileExists($s7ZAPath)) Then
	FileWriteLine($sLogFile, $s7ZAPath & " was not found, exiting script.")
	Exit
EndIf
FileCopy($s7ZAPath, @TempDir, 9) ; 9 = Overwrite and Create Dest Dir
FileWriteLine($sLogFile, "Copied 7za.exe to TempDir(" & @TempDir & "):" & @error)

; Begin to process ZIP files
FileWriteLine($sLogFile, "Beginning to process resource folders(src):" & $aDriverZips[0])

; Calculate amount of steps
$sTotalSteps = $aDriverZips[0] * 3
$sCurrentStep = 0
$sCurrentPercentComplete = fGrabPercentComplete(0)

; Create ProgressBar GUI
$oGUI = GUICreate("Panasonic Driver Installer v" & $sInstallVersion, 600, 130, 0, 0, $WS_BORDER, $WS_EX_TOPMOST) ;width, height, top, left
$oCompleteProgressLabel = GUICtrlCreateLabel("Complete Process:", 5, 10, 100, 20) ;left, top, width, height
$oCompleteProgressBar = GUICtrlCreateProgress(100, 5, 490, 20, $PBS_SMOOTH)
$oCompletePercentLabel = GUICtrlCreateLabel("", 100, 30, 100, 20)
$oCompleteProgressText = GUICtrlCreateLabel("", 200, 30, 385, 20, $SS_RIGHT)
$oStepProgressLabel = GUICtrlCreateLabel("Current Step:", 5, 65, 100, 20)
$oStepProgressBar = GUICtrlCreateProgress(100, 60, 490, 20, $PBS_SMOOTH)
$oStepPercentLabel = GUICtrlCreateLabel("", 100, 85, 100, 20)
$oStepProgressText = GUICtrlCreateLabel("", 200, 85, 385, 20, $SS_RIGHT)
GUISetState()

fProgressBars(0, "Beginning Tbook Installer...", 0, "")

; Begin cycling through Driver ZIPs
For $i = 1 To $aDriverZips[0]
	$sDriverZipPath = $sSrcPath & "\" & $aDriverZips[$i]
	$sDriverName = StringLeft($aDriverZips[$i], StringLen($aDriverZips[$i]) - 4) ;Remove file extension when updating progress bars
	FileWriteLine($sLogFile, "Processing " & $i & " of " & $aDriverZips[0] & "... (" & $aDriverZips[$i] & ")")
	fProgressBars($sCurrentPercentComplete, "Processing " & $i & " of " & $aDriverZips[0] & " packages in " & $sSrcFolderName & " bundle.", 30, "Beginning to process " & $sDriverName)

	; fProgressBars args: complete percent, text, step percent, text
	$sDriverExtractFolder = "C:\Drivers\" & $sSrcFolderName & "\" & StringTrimRight($aDriverZips[$i], 4) ; Specify extract folder, driver name without extension
	$sCurrentStep = $sCurrentStep + 1
	$sCurrentPercentComplete = fGrabPercentComplete($sCurrentStep)
	fProgressBars($sCurrentPercentComplete, "Processing " & $i & " of " & $aDriverZips[0] & " packages in " & $sSrcFolderName & " bundle.", 33, "Extracting " & $sDriverName)
	FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- Beggining to extract driver """ & $aDriverZips[$i] & """ to (" & $sDriverExtractFolder & "): ")
	$sRet = RunWait("cmd.exe /c 7za.exe x """ & $sDriverZipPath & """ -o""C:\Drivers\" & $sSrcFolderName & "\*"" -y", @TempDir, @SW_HIDE)

	FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- Completed extracting driver """ & $aDriverZips[$i] & """ to (" & $sDriverExtractFolder & "): " & $sRet)
	$sCurrentStep = $sCurrentStep + 1
	$sCurrentPercentComplete = fGrabPercentComplete($sCurrentStep)
	fProgressBars($sCurrentPercentComplete, "Processing " & $i & " of " & $aDriverZips[0] & " packages in " & $sSrcFolderName & " bundle.", 66, "Installing " & $sDriverName)
	If FileExists($sDriverExtractFolder & "\pnpid.txt") Then
		_FileReadToArray($sDriverExtractFolder & "\pnpid.txt", $aPNPIDContents)
		FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- PNPID file found, beginning WMI check for Device: " & $aPNPIDContents[1])
		If PNPCheck($aPNPIDContents[1]) Then
			FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- PNP Check returned successful for PNPID:" & $aPNPIDContents[1] & ": ")
			FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- Beginning to execute the PInstall.bat from extracted driver as PNPID Check returned successfull (" & $sDriverExtractFolder & "): ")
			$sRet = RunWait("cmd.exe /c pinstall.bat", $sDriverExtractFolder, @SW_HIDE)
		Else
			FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- Skipping install as PNPID Check returned Failed (" & $sDriverExtractFolder & "): ")
		EndIf
	Else
		FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- Beginning to execute the PInstall.bat from extracted driver (" & $sDriverExtractFolder & "): ")

		; Execution of PInsall
		$sRet = RunWait("cmd.exe /c pinstall.bat", $sDriverExtractFolder, @SW_HIDE)
	EndIf
	$sCurrentStep = $sCurrentStep + 1
	$sCurrentPercentComplete = fGrabPercentComplete($sCurrentStep)
	fProgressBars($sCurrentPercentComplete, "Processing " & $i & " of " & $aDriverZips[0] & " packages in " & $sSrcFolderName & " bundle.", 100, "Install of " & $sDriverName & " is complete.")
	Sleep(750) ; Delay to let user see install completed.
	FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- Completed executing the PInstall.bat from extracted driver (" & $sDriverExtractFolder & "): " & $sRet)

Next

FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- Script Execution is complete.")
$sRet = Run("TASKKILL /F /IM HideCmdWindowEvery3Sec.exe", @WindowsDir, @SW_HIDE)
FileWriteLine($sLogFile, @HOUR & ":" & @MIN & "--- Killed HideCmdWindowEvery3Sec.exe Process): " & $sRet)

GUIDelete($oGUI)
FileClose($sLogFile)

;================================================================================================================
; Functions and Sub Routines
;================================================================================================================
Func fGrabPercentComplete($sCurrentStep)
	Return Round(($sCurrentStep / $sTotalSteps) * 100)
EndFunc   ;==>fGrabPercentComplete

Func fProgressBars($sCompleteBarPerc, $sCompleteBarText, $sStepBarPerc, $sStepBarText) ;complete percent, text, step percent, text
	GUICtrlSetData($oCompleteProgressBar, $sCompleteBarPerc)
	GUICtrlSetData($oCompleteProgressText, $sCompleteBarText)
	GUICtrlSetData($oCompletePercentLabel, $sCompleteBarPerc & "%")
	GUICtrlSetData($oStepProgressBar, $sStepBarPerc)
	GUICtrlSetData($oStepProgressText, $sStepBarText)
	GUICtrlSetData($oStepPercentLabel, $sStepBarPerc & "%")
EndFunc   ;==>fProgressBars

Func PNPCheck($sPNPID)
	$sPNPID = StringReplace($sPNPID, '\', '%') ;Clean up PNPID string
	$objWMIService = ObjGet("winmgmts:\\.\root\cimv2")
	$sQuery = "Select * FROM Win32_PNPEntity WHERE DeviceID LIKE '%" & $sPNPID & "%'"
	$colPNPEntity = $objWMIService.ExecQuery($sQuery)
	Return $colPNPEntity.Count
EndFunc   ;==>PNPCheck