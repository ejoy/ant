copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\texturec%1.exe .\vs_bin\%1\texturec%1.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\shaderc%1.exe .\vs_bin\%1\shaderc%1.exe
copy /B /Y ..\..\3rd\build\ozz-animation\msvc\%1\src\animation\offline\gltf\gltf2ozz.exe .\vs_bin\%1\gltf2ozz.exe
copy /B /Y ..\..\3rd\bgfx\.build\win64_vs2019\bin\bgfx-shared-lib%1.dll .\vs_bin\%1\bgfx-core.dll

copy /B /Y ..\..\3rd\bgfx\src\bgfx_shader.sh ..\..\packages\resources\shaders\bgfx_shader.sh
copy /B /Y ..\..\3rd\bgfx\src\bgfx_compute.sh ..\..\packages\resources\shaders\bgfx_compute.sh
copy /B /Y ..\..\3rd\bgfx\examples\common\common.sh ..\..\packages\resources\shaders\common.sh
copy /B /Y ..\..\3rd\bgfx\examples\common\shaderlib.sh ..\..\packages\resources\shaders\shaderlib.sh

exit 0
