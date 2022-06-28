SetCompressor lzma

!addplugindir ".\plugins"
!addincludedir ".\includes"

; Modern user interface
!include "MUI2.nsh"
!include "UAC.nsh"
!include "WinVer.nsh"
!include x64.nsh

!define OPENVPN_ROOT "openvpn-bin"
!define QT_REDIST_ROOT "qt-redist"
!define QT_QML_ROOT "qml"
!define TAP_WINDOWS_INSTALLER "tap-windows.exe"
!define MASSIVE_SDK_INSTALLER "MassiveInstaller.exe"
!define VCREDIST_INSTALLER "vc-redist\vc_redist.x64.exe"
!define PACKAGE_NAME "JewelVPN"
!define VERSION_STRING "1.1"
!define MUI_ICON ".\icon.ico"
!define MUI_UNICON ".\icon.ico"
!define MASSIVE_APPID "{07F54E47-DE08-486E-921C-D09624774BB6}_is1"
!define REGISTER_UPATH "Software\Microsoft\Windows\CurrentVersion\Uninstall\"
;General

; Package name as shown in the installer GUI
Name "${PACKAGE_NAME} ${VERSION_STRING}"

; On 64-bit Windows the constant $PROGRAMFILES defaults to
; C:\Program Files (x86) and on 32-bit Windows to C:\Program Files. However,
; the .onInit function (see below) takes care of changing this for 64-bit 
; Windows.
InstallDir "$PROGRAMFILES\${PACKAGE_NAME}"

; Installer filename
OutFile "output\JewelVPN-installer-v1.1.exe"
RequestExecutionLevel Admin

 ShowInstDetails "nevershow"
 ShowUninstDetails "nevershow"

;--------------------------------
;Modern UI Configuration

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "license-text\license.rtf"
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\JewelVPN.exe"
!define MUI_FINISHPAGE_RUN_FUNCTION runApplication
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

;--------------------------------
;Languages
 
!insertmacro MUI_LANGUAGE "English"

Section "Kill processes"
	nsExec::ExecToLog 'taskkill /f /im JewelVPN.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im JewelVPNService.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im JewelVPNVideoAds.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im Massive.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im MassiveUI.exe'
	Pop $R0
SectionEnd


Section "OpenVPN binaries" SecOVPN
	SetOverwrite on
	SetOutPath "$INSTDIR"
	File /r "${OPENVPN_ROOT}\*.*"
SectionEnd

Section "TAP Virtual Ethernet Adapter" SecTAP
	SetOverwrite on
	SetOutPath "$TEMP"

	File /oname=tap-windows.exe "${TAP_WINDOWS_INSTALLER}"

	DetailPrint "Installing TAP (may need confirmation)..."
	nsExec::ExecToLog '"$TEMP\tap-windows.exe" /S /SELECT_UTILITIES=1'
	Pop $R0 # return value/error/timeout

	Delete "$TEMP\tap-windows.exe"

	WriteRegStr HKLM "${REGISTER_UPATH}${PACKAGE_NAME}" "tap" "installed"
SectionEnd

Section "Visual Studio 2017 Binaries" SecVC2017
	SetOverwrite on
	SetOutPath "$TEMP"

	File /oname=vc_redist.x64.exe "${VCREDIST_INSTALLER}"

	DetailPrint "Installing VC2017 binaries..."
	nsExec::ExecToLog '"$TEMP\vc_redist.x64.exe" /quiet'
	Pop $R0 # return value/error/timeout

	Delete "$TEMP\vc_redist.x64.exe"
SectionEnd

Section "JewelVPN binaries" SecMainApp
	SetOverwrite on

	; Copy redistributable DLLs
	SetOutPath "$INSTDIR"
	File /r "qml\*.*"
	File /r "massive\*.*"
	; Copy application binaries
	File /r "bin\*.*"
SectionEnd

Function .onInit

    ; Fail if trying to use tap-windows6 on Windows XP/Server 2003 or older
    ;
    ; Check whether the minor version number of the tap-windows driver has two
    ; numbers (tap-windows6) or just one (tap-windows). In the former case $0
    ; will have a number in it (9.2[1].1), and in the latter case a dot
    ; (9.9[.]2_3).
    StrCpy $0 "${TAP_WINDOWS_INSTALLER}" 1 15
    StrCmp $0 "." has_tap_windows has_tap_windows6

    has_tap_windows6:
        ${If} ${AtMostWinXP}
        ${OrIf} ${IsWin2003}
            MessageBox MB_OK "This installer only works on Windows Vista, Windows Server 2008 and above"
            Quit
        ${EndIf}
    has_tap_windows:

	SetShellVarContext all
FunctionEnd

Function .onInstSuccess
	SetShellVarContext all
FunctionEnd

Function runApplication 
	ExecShell "" "$INSTDIR\JewelVPN.exe"
FunctionEnd

Section -post

	SetOverwrite on
	SetOutPath "$INSTDIR"

	nsExec::ExecToLog '"$INSTDIR\JewelVPNService.exe" deploy'
	nsExec::ExecToLog '"$INSTDIR\JewelVPNService.exe" start'

	; Store install folder in registry
	WriteRegStr HKLM "SOFTWARE\${PACKAGE_NAME}" "" "$INSTDIR"

	; Create uninstaller
	WriteUninstaller "$INSTDIR\Uninstall.exe"

	; Show up in Add/Remove programs
	WriteRegStr HKLM "${REGISTER_UPATH}${PACKAGE_NAME}" "DisplayName" "${PACKAGE_NAME} ${VERSION_STRING}"
	WriteRegExpandStr HKLM "${REGISTER_UPATH}${PACKAGE_NAME}" "UninstallString" "$INSTDIR\Uninstall.exe"
	WriteRegStr HKLM "${REGISTER_UPATH}${PACKAGE_NAME}" "DisplayIcon" "$INSTDIR\Uninstall.exe"
	WriteRegStr HKLM "${REGISTER_UPATH}${PACKAGE_NAME}" "DisplayVersion" "${VERSION_STRING}"

	; Massive Entry Start
	WriteRegStr HKCU "Software\Massive" "InstallPath" "$INSTDIR\Massive"
	WriteRegStr HKCU "Software\Massive" "TrackingIds" "UA-135690027-7"

	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "Inno Setup: Setup Version" "6.0.3 (u)"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "Inno Setup: App Path" "$INSTDIR\Massive"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "InstallLocation" "$INSTDIR\Massive\"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "Inno Setup: Icon Group" "Massive"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "Inno Setup: User" "jewelvpn"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "Inno Setup: Language" "en"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "DisplayName" "Massive"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "DisplayIcon" "$INSTDIR\Massive\MassiveUI.exe"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "UninstallString" "\$\"$INSTDIR\Massive\unins000.exe\$\""
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "QuietUninstallString" "\$\"$INSTDIR\Massive\unins000.exe\$\" /SILENT"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "DisplayVersion" "0.10.2.0"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "Publisher" "Massive Computing, Inc."
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "URLInfoAbout" "https://joinmassive.com/"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "HelpLink" "https://joinmassive.com/"
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "URLUpdateInfo" "https://joinmassive.com/"
	WriteRegDWORD HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "NoModify" 0x1
	WriteRegDWORD HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "NoRepair" 0x1
	WriteRegStr HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "InstallDate" "20220411"
	WriteRegDWORD HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "MajorVersion" 0x0
	WriteRegDWORD HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "MinorVersion" 0xa
	WriteRegDWORD HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "VersionMajor" 0x0
	WriteRegDWORD HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "VersionMinor" 0xa
	WriteRegDWORD HKCU "${REGISTER_UPATH}${MASSIVE_APPID}" "EstimatedSize" 0x10921

	; Massive Entry End

	; Create entry in start menu
	CreateDirectory "$SMPROGRAMS\${PACKAGE_NAME}"
	CreateShortCut "$SMPROGRAMS\${PACKAGE_NAME}\${PACKAGE_NAME}.lnk" "$INSTDIR\JewelVPN.exe" "" ""

	
	;create desktop shortcut
	CreateShortCut "$DESKTOP\JewelVPN.lnk" "$INSTDIR\JewelVPN.exe" ""

	; Add autorun entry
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PACKAGE_NAME}" "$INSTDIR\JewelVPN.exe"
	
	; Add Massive Entry
	WriteRegStr HKCU "Software\Massive" "InstallPath" "$INSTDIR\Massive"
	WriteRegDWORD HKCU "Software\Massive" "IsComputationEnabled" "1"
SectionEnd

Function un.onInit
	ClearErrors
	SetShellVarContext all
FunctionEnd

Section "Uninstall"

	; Stop JewelVPN if currently running

	nsExec::ExecToLog '"$INSTDIR\JewelVPNService.exe" stop'
	Pop $R0
	nsExec::ExecToLog '"$INSTDIR\JewelVPNService.exe" undeploy'
	Pop $R0 # return value/error/timeout

	nsExec::ExecToLog 'taskkill /f /im JewelVPN.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im JewelVPNService.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im JewelVPNVideoAds.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im Massive.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im MassiveUI.exe'
	Pop $R0

	Sleep 3000

	ReadRegStr $R0 HKLM "${REGISTER_UPATH}${PACKAGE_NAME}" "tap"
	${If} $R0 == "installed"
		ReadRegStr $R0 HKLM "${REGISTER_UPATH}TAP-Windows" "UninstallString"
		${If} $R0 != ""
			DetailPrint "Uninstalling TAP..."
			nsExec::ExecToLog '"$R0" /S'
			Pop $R0 # return value/error/timeout
		${EndIf}
	${EndIf}


	Delete "$SMPROGRAMS\${PACKAGE_NAME}\${PACKAGE_NAME}.lnk"
	RmDir "$SMPROGRAMS\${PACKAGE_NAME}" 
    
	RmDir /r $INSTDIR

	DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PACKAGE_NAME}"
	
	; Remove Massive Entry
	DeleteRegKey HKCU "Software\Massive"
	DeleteRegKey HKLM "${REGISTER_UPATH}${MASSIVE_APPID}"

	; Remove Jewel Entry
	DeleteRegKey HKLM "${REGISTER_UPATH}${PACKAGE_NAME}"
SectionEnd