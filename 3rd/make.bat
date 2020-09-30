call scripts\msvc.bat

msbuild build\ozz-animation\msvc\%1\ozz.sln             /m /v:m /t:build /p:Configuration="%1",Platform="x64"
msbuild build\reactphysics3d\msvc\%1\REACTPHYSICS3D.sln /m /v:m /t:build /p:Configuration="%1",Platform="x64"
msbuild build\RmlUi\msvc\%1\RmlUi.sln                   /m /v:m /t:build /p:Configuration="%1",Platform="x64"
msbuild bgfx\.build\projects\vs2019\bgfx.sln            /m /v:m /t:build /p:Configuration="%1",Platform="x64"

copy /B /Y bgfx\.build\win64_vs2019\bin\texturec%1.exe ..\bin\msvc\%1\texturec.exe
copy /B /Y bgfx\.build\win64_vs2019\bin\shaderc%1.exe ..\bin\msvc\%1\shaderc.exe
copy /B /Y bgfx\.build\win64_vs2019\bin\bgfx-shared-lib%1.dll ..\bin\msvc\%1\bgfx-core.dll
copy /B /Y bgfx\src\bgfx_shader.sh ..\packages\resources\shaders\bgfx_shader.sh
copy /B /Y bgfx\src\bgfx_compute.sh ..\packages\resources\shaders\bgfx_compute.sh
copy /B /Y bgfx\examples\common\common.sh ..\packages\resources\shaders\common.sh
copy /B /Y bgfx\examples\common\shaderlib.sh ..\packages\resources\shaders\shaderlib.sh
copy /B /Y build\ozz-animation\msvc\%1\src\animation\offline\gltf\gltf2ozz.exe ..\bin\msvc\%1\gltf2ozz.exe
