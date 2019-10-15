set Configuration=%1
set binpath=vs_bin\%Configuration%
set shaderinputpath=packages\imguibase\shader
set msvcprojectpath=projects\msvc
set shaderoutputpath=tools\firmware\o\%Configuration%\msvc
mkdir -p %shaderoutputpath%
set originpath=%cd%
cd ..\..
echo %cd%
%msvcprojectpath%\%binpath%\lua.exe tools\shaderc\main.lua .windows_direct3d11 %shaderinputpath%\fs_imgui_image.sc   %msvcprojectpath%\%shaderoutputpath%\fs_imgui_image.sc --bin=msvc
%msvcprojectpath%\%binpath%\lua.exe tools\shaderc\main.lua .windows_direct3d11 %shaderinputpath%\vs_imgui_image.sc   %msvcprojectpath%\%shaderoutputpath%\vs_imgui_image.sc --bin=msvc
%msvcprojectpath%\%binpath%\lua.exe tools\shaderc\main.lua .windows_direct3d11 %shaderinputpath%\fs_imgui_font.sc    %msvcprojectpath%\%shaderoutputpath%\fs_imgui_font.sc --bin=msvc
%msvcprojectpath%\%binpath%\lua.exe tools\shaderc\main.lua .windows_direct3d11 %shaderinputpath%\vs_imgui_font.sc    %msvcprojectpath%\%shaderoutputpath%\vs_imgui_font.sc --bin=msvc
cd %originpath%

%binpath%\incbin.exe -Dtools\firmware\o\%Configuration%\msvc ..\..\clibs\firmware\firmware.cpp -o tools\data.c

exit 0