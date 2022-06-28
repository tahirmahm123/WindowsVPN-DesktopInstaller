SET NSIS="C:\Program Files (x86)\NSIS\makensis.exe"
SET BASH="C:\Program Files\Git\bin\bash.exe"

:make_nsis

%NSIS% installer.nsi
