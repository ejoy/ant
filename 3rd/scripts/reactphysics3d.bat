call scripts\msvc.bat

msbuild build\reactphysics3d\msvc\%1\REACTPHYSICS3D.sln /m /v:m /t:build /p:Configuration="%1",Platform="x64"
