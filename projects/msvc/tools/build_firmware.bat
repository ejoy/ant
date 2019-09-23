set Configuration=%1
set binpath=vs_bin\%Configuration%
set shaderinputpath=packages\imguibase\shader
set msvcprojectpath=projects\msvc
set shaderoutputpath=%msvcprojectpath%\tools\firmware\o\%Configuration%\msvc
mkdir %shaderoutputpath%
set originpath=%cd%
cd ..\..
echo %cd%
%msvcprojectpath%\%binpath%\lua.exe tools\shaderc\main.lua .windows_direct3d11 %shaderinputpath%\fs_imgui_image.sc      %shaderoutputpath%\fs_imgui_image.sc
%msvcprojectpath%\%binpath%\lua.exe tools\shaderc\main.lua .windows_direct3d11 %shaderinputpath%\fs_ocornut_imgui.sc    %shaderoutputpath%\fs_ocornut_imgui.sc
%msvcprojectpath%\%binpath%\lua.exe tools\shaderc\main.lua .windows_direct3d11 %shaderinputpath%\vs_imgui_image.sc      %shaderoutputpath%\vs_imgui_image.sc
%msvcprojectpath%\%binpath%\lua.exe tools\shaderc\main.lua .windows_direct3d11 %shaderinputpath%\vs_ocornut_imgui.sc    %shaderoutputpath%\vs_ocornut_imgui.sc
cd %originpath%

%binpath%\incbin.exe -Dtools\firmware\o\%Configuration%\msvc ..\..\clibs\firmware\firmware.cpp -o tools\data.c