ManifestDPIAware true

SetCompressor lzma

!addplugindir ".\plugins"
!addincludedir ".\includes"

; Modern user interface
!include "MUI2.nsh"
!include "UAC.nsh"
!include "WinVer.nsh"
!include x64.nsh
!include nsDialogs.nsh

!define OPENVPN_ROOT "bin"
!define QT_REDIST_ROOT "qt-redist"
!define QT_QML_ROOT "qml"
!define TAP_WINDOWS_INSTALLER "tap-windows.exe"
!define VCREDIST_INSTALLER "vc-redist\vc_redist.x64.exe"
!define PACKAGE_NAME "JewelVPN"
!define VERSION_STRING "1.2"
!define MUI_ICON ".\icon.ico"
!define MUI_UNICON ".\icon.ico"
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
OutFile "JewelVPN-installer-v1.2.exe"
RequestExecutionLevel Admin

 ShowInstDetails "nevershow"
 ShowUninstDetails "nevershow"

;--------------------------------
;Modern UI Configuration

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "license-text\license.rtf"
Page custom CreateMassivePage LeaveMassivePage
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
SectionEnd


Section "OpenVPN binaries" SecOVPN
    SetOverwrite on
    SetOutPath "$INSTDIR"
    File /r "${OPENVPN_ROOT}\*.*"
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

Var Dialog
Var MassiveLicenseAgreementLink
Var MassivePrivacyPolicyLink
Var MassiveFAQLink

Function CreateMassivePage
    !insertmacro MUI_HEADER_TEXT "Massive service" "Please review the license terms before installing Massive."

    GetDlgItem $0 $hwndparent 1
    SendMessage $0 ${WM_SETTEXT} 0 `STR:Accept` ; Install -> Accept

    GetDlgItem $0 $hwndparent 2
    SendMessage $0 ${WM_SETTEXT} 0 `STR:Decline` ; Cancel -> Decline

    nsDialogs::Create 1018
        Pop $Dialog

    ${If} $Dialog == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0u 0u 100% 30u "JewelVPN lets you anonymously access the internet for free in exchange for a small amount of your unused processing power, storage, and bandwidth managed by Massive. You can monitor and adjust this resource use anytime by pressing the Massive taskbar icon to open the controls."
        Pop $0

    ${NSD_CreateLabel} 0u 35u 100% 30u "Your idle computing resources are used to mine cryptocurrency, run scientific simulations, and perform other disributed tasks, which may increase electricity consumption or decrease battery life (see Massive's FAQ for details)."
        Pop $0

    ${NSD_CreateLabel} 0u 70u 100% 10u "Pressing $\"Accept$\" indicates that you agree to Massive's license and privacy policy."
        Pop $0

    ${NSD_CreateLink} 10u 90u 100% 10u "License agreement"
        Pop $MassiveLicenseAgreementLink
        ${NSD_OnClick} $MassiveLicenseAgreementLink MassiveLicenseAgreementLinkClicked

    ${NSD_CreateLink} 10u 100u 100% 10u "Privacy policy"
        Pop $MassivePrivacyPolicyLink
        ${NSD_OnClick} $MassivePrivacyPolicyLink MassivePrivacyPolicyLinkClicked

    ${NSD_CreateLink} 10u 110u 100% 10u "FAQ"
        Pop $MassiveFAQLink
        ${NSD_OnClick} $MassiveFAQLink MassiveFAQLinkClicked

    nsDialogs::Show
FunctionEnd

Function LeaveMassivePage
FunctionEnd

Function MassiveLicenseAgreementLinkClicked
    ExecShell "open" "https://joinmassive.com/terms"
FunctionEnd

Function MassivePrivacyPolicyLinkClicked
    ExecShell "open" "https://joinmassive.com/privacy"
FunctionEnd

Function MassiveFAQLinkClicked
    ExecShell "open" "https://joinmassive.com/faq#users"
FunctionEnd

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

    ; Create entry in start menu
    CreateDirectory "$SMPROGRAMS\${PACKAGE_NAME}"
    CreateShortCut "$SMPROGRAMS\${PACKAGE_NAME}\${PACKAGE_NAME}.lnk" "$INSTDIR\JewelVPN.exe" "" ""

    
    ;create desktop shortcut
    CreateShortCut "$DESKTOP\JewelVPN.lnk" "$INSTDIR\JewelVPN.exe" ""

    ; Add autorun entry
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PACKAGE_NAME}" "$INSTDIR\JewelVPN.exe"
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

    ; Remove Jewel Entry
    DeleteRegKey HKLM "${REGISTER_UPATH}${PACKAGE_NAME}"
SectionEnd