local assimp = require"assimplua"
local inpath = "D:/Engine/ant/clibs/assimplua/assets/sword.fbx"
local outpath = "D:/Engine/ant/clibs/assimplua/assets/sword.bin"
assimp.assimp_import(inpath, outpath)
