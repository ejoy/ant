@echo off
if "%1" == "" (
    set BUILD_MODE=Debug
    call make init PLAT=msvc MODE=%BUILD_MODE%
) else (
    set BUILD_MODE=%1
)

if "%2" == "MAKE_OZZ_GLTF_TOOL" (
    set OZZ_GLTF_TOOL=build\ozz-animation\msvc\%BUILD_MODE%\src\animation\offline\gltf\gltf2ozz.exe
) else (
    set OZZ_GLTF_TOOL=tools\msvc\gltf2ozz.exe
)

@echo on

call scripts\msvc.bat

msbuild build\ozz-animation\msvc\%BUILD_MODE%\ozz.sln             /m /v:m /t:build /p:Configuration="%BUILD_MODE%",Platform="x64"
msbuild build\reactphysics3d\msvc\%BUILD_MODE%\REACTPHYSICS3D.sln /m /v:m /t:build /p:Configuration="%BUILD_MODE%",Platform="x64"
msbuild bgfx\.build\projects\vs2019\bgfx.sln            /m /v:m /t:build /p:Configuration="%BUILD_MODE%",Platform="x64"

copy /B /Y bgfx\.build\win64_vs2019\bin\texturec%BUILD_MODE%.exe ..\bin\msvc\%BUILD_MODE%\texturec.exe
copy /B /Y bgfx\.build\win64_vs2019\bin\shaderc%BUILD_MODE%.exe ..\bin\msvc\%BUILD_MODE%\shaderc.exe
copy /B /Y bgfx\.build\win64_vs2019\bin\bgfx-shared-lib%BUILD_MODE%.dll ..\bin\msvc\%BUILD_MODE%\bgfx-core.dll
copy /B /Y bgfx\src\bgfx_shader.sh ..\packages\resources\shaders\bgfx_shader.sh
copy /B /Y bgfx\src\bgfx_compute.sh ..\packages\resources\shaders\bgfx_compute.sh
copy /B /Y bgfx\examples\common\common.sh ..\packages\resources\shaders\common.sh
copy /B /Y bgfx\examples\common\shaderlib.sh ..\packages\resources\shaders\shaderlib.sh
copy /B /Y %OZZ_GLTF_TOOL% ..\bin\msvc\%BUILD_MODE%\gltf2ozz.exe
