devenv build\assimp\msvc\Assimp.sln /Build "Debug|x64"
devenv build\freetype\msvc\freetype.sln /Build "Debug|x64"
devenv build\ozz-animation\msvc\ozz.sln /Build "Debug|x64"
devenv build\zlib\msvc\zlib.sln /Build "Debug|x64"
devenv build\bullet3\msvc\BULLET_PHYSICS.sln /Build "Debug|x64"

devenv cd\mak.vc15\cd.sln /Build Debug /project cd\mak.vc15\cd.vcxproj /projectconfig "Debug|x64" /project cd\mak.vc15\cdlua.vcxproj /projectconfig "Debug|x64"

devenv bgfx\.build\projects\vs2017\bgfx.sln /Build "Debug|x64"
devenv ib-compress\ib-compress.sln /Build "Debug|x64"