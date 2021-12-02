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
!define VCREDIST_INSTALLER "vc-redist\vc_redist.x64.exe"
!define PACKAGE_NAME "JewelVPN"
!define VERSION_STRING "1.0"
!define MUI_ICON ".\icon.ico"
!define MUI_UNICON ".\icon.ico"

;General

; Package name as shown in the installer GUI
Name "${PACKAGE_NAME} ${VERSION_STRING}"

; On 64-bit Windows the constant $PROGRAMFILES defaults to
; C:\Program Files (x86) and on 32-bit Windows to C:\Program Files. However,
; the .onInit function (see below) takes care of changing this for 64-bit 
; Windows.
InstallDir "$PROGRAMFILES\${PACKAGE_NAME}"

; Installer filename
OutFile "output\JewelVPN-installer.exe"
RequestExecutionLevel Admin

 ShowInstDetails "nevershow"
 ShowUninstDetails "nevershow"

;--------------------------------
;Modern UI Configuration

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\bin\JewelVPN.exe"
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
	nsExec::ExecToLog 'taskkill /f /im infatica-service-app.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im JewelVPNService.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im JewelVPNVideoAds.exe'
	Pop $R0

SectionEnd


Section "OpenVPN binaries" SecOVPN
	SetOverwrite on
	SetOutPath "$INSTDIR\bin"
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

	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "tap" "installed"
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
	SetOutPath "$INSTDIR\bin"
	File /r "qml\*.*"
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
	ExecShell "" "$INSTDIR\bin\JewelVPN.exe"
FunctionEnd

Section -post

	SetOverwrite on
	SetOutPath "$INSTDIR"

	nsExec::ExecToLog '"$INSTDIR\bin\JewelVPNService.exe" deploy'
	nsExec::ExecToLog '"$INSTDIR\bin\JewelVPNService.exe" start'

	; Store install folder in registry
	WriteRegStr HKLM "SOFTWARE\${PACKAGE_NAME}" "" "$INSTDIR"

	; Create uninstaller
	WriteUninstaller "$INSTDIR\Uninstall.exe"

	; Show up in Add/Remove programs
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "DisplayName" "${PACKAGE_NAME} ${VERSION_STRING}"
	WriteRegExpandStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "UninstallString" "$INSTDIR\Uninstall.exe"
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "DisplayIcon" "$INSTDIR\Uninstall.exe"
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "DisplayVersion" "${VERSION_STRING}"

	; Create entry in start menu
	CreateDirectory "$SMPROGRAMS\${PACKAGE_NAME}"
	CreateShortCut "$SMPROGRAMS\${PACKAGE_NAME}\${PACKAGE_NAME}.lnk" "$INSTDIR\bin\JewelVPN.exe" "" ""

	;create desktop shortcut
	CreateShortCut "$DESKTOP\JewelVPN.lnk" "$INSTDIR\bin\JewelVPN.exe" ""

	; Add autorun entry
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PACKAGE_NAME}" "$INSTDIR\bin\JewelVPN.exe"
SectionEnd

Function un.onInit
	ClearErrors
	SetShellVarContext all
FunctionEnd

Section "Uninstall"

	; Stop JewelVPN if currently running

	nsExec::ExecToLog '"$INSTDIR\bin\JewelVPNService.exe" stop'
	Pop $R0
	nsExec::ExecToLog '"$INSTDIR\bin\JewelVPNService.exe" undeploy'
	Pop $R0 # return value/error/timeout

	nsExec::ExecToLog 'taskkill /f /im JewelVPN.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im infatica-service-app.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im JewelVPNService.exe'
	Pop $R0
	nsExec::ExecToLog 'taskkill /f /im JewelVPNVideoAds.exe'
	Pop $R0

	Sleep 3000

	ReadRegStr $R0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "tap"
	${If} $R0 == "installed"
		ReadRegStr $R0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\TAP-Windows" "UninstallString"
		${If} $R0 != ""
			DetailPrint "Uninstalling TAP..."
			nsExec::ExecToLog '"$R0" /S'
			Pop $R0 # return value/error/timeout
		${EndIf}
	${EndIf}

	Delete "$SMPROGRAMS\${PACKAGE_NAME}\${PACKAGE_NAME}.lnk"
	RmDir "$SMPROGRAMS\${PACKAGE_NAME}" 
    
	RmDir /r $INSTDIR\bin

	Delete "$INSTDIR\Uninstall.exe"

	RMDir "$INSTDIR"

	DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PACKAGE_NAME}"
	DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}"
SectionEnd