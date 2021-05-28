set wdir=..\..\..
%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type fragment -p ps_5_0 -f fs_scene.sc -o mesh\fs_scene.bin --depends -i %wdir%\packages\resources\shaders
%wdir%\bin\msvc\Debug\shaderc.exe --platform windows --type vertex -p vs_5_0 -f vs_scene.sc -o mesh\vs_scene.bin --depends -i %wdir%\packages\resources\shaders