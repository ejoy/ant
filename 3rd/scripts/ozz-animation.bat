call scripts\msvc.bat

msbuild build\ozz-animation\msvc\%1\ozz.sln      /m /v:m /t:build /p:Configuration="%1",Platform="x64"

copy /B /Y build\ozz-animation\msvc\%1\src\animation\offline\gltf\gltf2ozz.exe ..\projects\msvc\vs_bin\%1\gltf2ozz.exe
