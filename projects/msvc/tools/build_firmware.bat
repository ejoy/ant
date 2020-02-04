set Configuration=%1
set binpath=vs_bin\%Configuration%
set shaderinputpath=packages\imguibase\shader
set msvcprojectpath=projects\msvc
set shaderoutputpath=tools\firmware\o\%Configuration%\msvc
mkdir %shaderoutputpath%
%binpath%\incbin.exe -Dtools\firmware\o\%Configuration%\msvc ..\..\clibs\firmware\firmware.cpp -o tools\data.c

exit 0