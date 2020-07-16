set Configuration=%1
set binpath=..\..\bin\msvc\%Configuration%
%binpath%\incbin.exe -Dtools\firmware\o\%Configuration%\msvc ..\..\clibs\firmware\firmware.cpp -o tools\data.c
