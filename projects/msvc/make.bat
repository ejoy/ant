call 3rd\scripts\msvc.bat

msbuild projects\msvc\ant.sln /m /v:m /t:build /p:Configuration="%1",Platform="x64"