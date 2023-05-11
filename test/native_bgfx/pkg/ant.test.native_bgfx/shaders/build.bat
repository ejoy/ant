set wdir=..\..\..\..\..
set shaderinc=%wdir%\pkg\ant.resources\shaders
%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type fragment -p s_5_0 -f mesh\fs_mesh.sc -o mesh\fs_mesh.bin --depends -i %shaderinc% --debug
%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type vertex -p s_5_0 -f mesh\vs_mesh.sc -o mesh\vs_mesh.bin --depends -i %shaderinc% --debug

%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type fragment -p s_5_0 -f fullquad\fs_quad.sc -o fullquad\fs_quad.bin --depends -i %shaderinc% --debug
%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type vertex -p s_5_0 -f fullquad\vs_quad.sc -o fullquad\vs_quad.bin --depends -i %shaderinc% --debug