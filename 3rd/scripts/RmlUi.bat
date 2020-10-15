call scripts\msvc.bat

msbuild build\RmlUi\msvc\%1\RmlUi.sln      /m /v:m /t:build /p:Configuration="%1",Platform="x64"
