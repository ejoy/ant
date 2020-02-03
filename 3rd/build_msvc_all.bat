@echo off

for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
  set InstallDir=%%i
)

call "%InstallDir%\Common7\Tools\vsdevcmd.bat" -arch=x64 -host_arch=x64

@echo on

msbuild build\ozz-animation\msvc\%1\ozz.sln      /m /v:m /t:build /p:Configuration="%1",Platform="x64"
msbuild build\bullet3\msvc\%1\BULLET_PHYSICS.sln /m /v:m /t:build /p:Configuration="%1",Platform="x64"
msbuild bgfx\.build\projects\vs2019\bgfx.sln        /m /v:m /t:build /p:Configuration="%1",Platform="x64"
