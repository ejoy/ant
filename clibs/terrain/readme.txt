=== clibs/terrain 地形模块 ===

    terrain.lua            地形用户层 LUA API 
    terrain.cpp           c dll提供快速计算,只给 terrain.lua 使用，向上层用户屏蔽 

    terrain.lua            lua layer API 
    terrain.cpp           c layer API 

--- util_* 辅助函数----
    utilclass.lua          字典表，类模拟 LUA 函数
    utilmath.lua         构造 direction 的数学函数
    utiltexture.lua      纹理加载函数(与ant framework 合并时会删除）

---  测试程序文件 ---
test_*.lua 
    test_class.lua        lua class usage 
    test_lterrain.lua    lterrain.dll usage
    test_tex.lua          texload usage 

	
=== 资源文件 === 

--- 地形关卡文件 ---
pvp.lvl 
    terrain level config sample 

--- 纹理及配置文件目录 ---
    terrain resource directory: /Work/ant/assets/build/terrain

-- shader 文件目录 ----
    terrain shader source directory: /Work/ant/assets/shaders/src/terrain

--- 纹理转换格式 ------
base and mask images  must convert to dds
     base  with mipmap format = bc3 
     mask  without mipmap

	 
	 
	 
合并编译：
    拷贝 terrain.cpp 到 clibs/bgfx
    修改 bgfx 下的makefile 增加 terrain.cpp
    修改 terrain.cpp 文件的输出接口,
        luaopen_lterrain 改为 luaopen_bgfx_terrain
    作为bgfx工程的一个子模块编译 
    lua layer terrain api 访问时，使用 require "bgfx.terrain"

	
	