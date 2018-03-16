local assimp = require"assimplua"
local inpath = "D:/Engine/ant/clibs/assimp-lua/assets/sword.fbx"
local outpath = "D:/Engine/ant/clibs/assimp-lua/assets/sword.bin"
assimp.assimp_import(inpath, outpath)
