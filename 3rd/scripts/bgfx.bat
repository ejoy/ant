call scripts\msvc.bat

msbuild bgfx\.build\projects\vs2019\bgfx.sln     /m /v:m /t:build /p:Configuration="%1",Platform="x64"

copy /B /Y bgfx\.build\win64_vs2019\bin\texturec%1.exe ..\projects\msvc\vs_bin\%1\texturec%1.exe
copy /B /Y bgfx\.build\win64_vs2019\bin\shaderc%1.exe ..\projects\msvc\vs_bin\%1\shaderc%1.exe
copy /B /Y bgfx\.build\win64_vs2019\bin\bgfx-shared-lib%1.dll ..\projects\msvc\vs_bin\%1\bgfx-core.dll
copy /B /Y bgfx\src\bgfx_shader.sh ..\packages\resources\shaders\bgfx_shader.sh
copy /B /Y bgfx\src\bgfx_compute.sh ..\packages\resources\shaders\bgfx_compute.sh
copy /B /Y bgfx\examples\common\common.sh ..\packages\resources\shaders\common.sh
copy /B /Y bgfx\examples\common\shaderlib.sh ..\packages\resources\shaders\shaderlib.sh
