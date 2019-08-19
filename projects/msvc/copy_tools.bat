copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\texturecDebug.exe     .\vs_bin\Debug\texturecDebug.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\texturecRelease.exe   .\vs_bin\Release\texturecRelease.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\texturecRelease.exe   ..\..\bin\msvc\texturec.exe

copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\shadercDebug.exe      .\vs_bin\Debug\shadercDebug.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\shadercRelease.exe    .\vs_bin\Release\shadercRelease.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\shadercRelease.exe    ..\..\bin\msvc\shaderc.exe

copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\bgfx-shared-libDebug.dll      .\vs_bin\Debug\bgfx-core.dll
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\bgfx-shared-libRelease.dll    .\vs_bin\Release\bgfx-core.dll