## clibs/terrain 地形模块 ===
    terrainclass.lua      lua layer API 地形用户层 LUA API 
    terrain.cpp           c dll提供快速计算,只给 terrainclass.lua 使用，向上层用户屏蔽 

## 文件变动    
   terrainclass.lua 本意是个api 提供给 sys 使用，
   目前被移动到 libs/scene/terrain 目录下，有一个备份版本
   当前仍以clibs/terrain 目录为主，两个会同步，或后续固定下来，
   注意这个差别

## clibs/terrain/util_* 辅助函数
    utilclass.lua        字典表，类模拟 LUA 函数,方便用来构建类变量
    utilmath.lua         构造 direction 的数学函数
    utiltexture.lua      纹理加载函数(与ant framework 合并时会删除）


##  测试程序文件 ====
test_*.lua 
    test_class.lua       lua class usage 
    test_terrain.lua     lterrain.dll usage
    test_tex.lua         texload usage 
    有过几次修改，测试例子不一定能正确运行

	
## 资源文件 === 

### 地形 shader 
    fs_terrain.sc/vs_terrain.sc
    存放于 ant/assets/shaders/src/terrain 目录下

### 地形材质文件 
    terrain.mtl  不同地形实例存在不同的 material
    地形有些特殊，可以独立格式，但未来也可以考虑和 mesh 的 material 格式兼容

### 地形关卡文件 ---
pvp.lvl 模板
    terrain level config sample 
    记录地形的总体几何信息，纹理等一个地形实例的所需内容
    地形关卡实例以一个独立的,

### 关卡文件存放目录    
    /Work/ant/assets/build/terrain/*.lvl,*.mtl,*.data,*.jpg,*.png etc 
    这部分可以在最终场景文件保存方式和位置确定后，可根据规划的目录调整存放

## 一些工具,用来做纹理格式转换 ------
    textureC.exe 纹理编译器
    base = 基础贴图, mask = 掩码贴图
    base and mask images  must convert to [dds]
    base  with mipmap format = bc3 
    mask  without mipmap
	 
## 合并编译 ==：

    ### for ios
    拷贝 terrain.cpp 到 clibs/bgfx
    修改 bgfx 下的makefile 增加 terrain.cpp
    修改 terrain.cpp 文件的输出接口,
        luaopen_lterrain 改为 luaopen_bgfx_terrain
    作为bgfx工程的一个子模块编译 
    lua layer terrain api 访问时，使用 require "bgfx.terrain"
