@echo

set wdir=..\..\..\..\..
set shaderinc=%wdir%\pkg\ant.resources\shaders

set windowsdir=bin\windows
%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type fragment -p s_5_0 -f mesh\fs_mesh.sc -o %windowsdir%\fs_mesh.bin --depends -i %shaderinc% --debug
%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type vertex -p s_5_0 -f mesh\vs_mesh.sc -o %windowsdir%\vs_mesh.bin --depends -i %shaderinc% --debug

%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type fragment -p s_5_0 -f fullquad\fs_quad.sc -o %windowsdir%\fs_quad.bin --depends -i %shaderinc% --debug
%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type vertex -p s_5_0 -f fullquad\vs_quad.sc -o %windowsdir%\vs_quad.bin --depends -i %shaderinc% --debug

set androiddir=bin\android
%wdir%\bin\msvc\Debug\shaderc.exe --platform android --type fragment -p spirv -f mesh\fs_mesh.sc -o %androiddir%\fs_mesh.bin --depends -i %shaderinc% --debug
%wdir%\bin\msvc\Debug\shaderc.exe --platform android --type vertex -p spirv -f mesh\vs_mesh.sc -o %androiddir%\vs_mesh.bin --depends -i %shaderinc% --debug

%wdir%\bin\msvc\Debug\shaderc.exe --platform android --type fragment -p spirv -f fullquad\fs_quad.sc -o %androiddir%\fs_quad.bin --depends -i %shaderinc% --debug
%wdir%\bin\msvc\Debug\shaderc.exe --platform android --type vertex -p spirv -f fullquad\vs_quad.sc -o %androiddir%\vs_quad.bin --depends -i %shaderinc% --debug