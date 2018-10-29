devenv build_msvc\assimp\Assimp.sln /Build "Debug|x64"
devenv build_msvc\freetype\freetype.sln /Build "Debug|x64"
devenv build_msvc\ozz-animation\ozz.sln /Build "Debug|x64"
devenv build_msvc\zlib\zlib.sln /Build "Debug|x64"
devenv build_msvc\bullet3\BULLET_PHYSICS.sln /Build "Debug|x64"

devenv cd\mak.vc15\cd.sln /Build Debug /project cd\mak.vc15\cd.vcxproj /projectconfig "Debug|x64" /project cd\mak.vc15\cdlua.vcxproj /projectconfig "Debug|x64"

devenv bgfx\.build\projects\vs2017\bgfx.sln /Build "Debug|x64"