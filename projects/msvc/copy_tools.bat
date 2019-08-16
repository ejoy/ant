copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\texturecDebug.exe     .\vs_bin\x64\Debug\texturecDebug.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\texturecRelease.exe   .\vs_bin\x64\Release\texturecRelease.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\texturecRelease.exe   ..\..\bin\texturec.exe

copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\shadercDebug.exe      .\vs_bin\x64\Debug\shadercDebug.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\shadercRelease.exe    .\vs_bin\x64\Release\shadercRelease.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\shadercRelease.exe    ..\..\bin\shaderc.exe

copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\bgfx-shared-libDebug.dll      .\vs_bin\x64\Debug\bgfx-core.dll
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\bgfx-shared-libRelease.dll    .\vs_bin\x64\Release\bgfx-core.dll