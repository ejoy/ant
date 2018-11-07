### clibs document
- 文件夹的名称代表的是库的名称，也和对应编译出来的库的名称是一样的（如，math3d文件夹，编译出来的是math3d.dll/math3d.lib/libmath3d.a）；
- 库文件夹下面的lua文件夹是对库的再一次封装，对应的目录已经在lua的搜索路径里面，详细看init.lua下，对lua path的设置；


#### assimplua
模型导入相关，包括将fbx、bgfx的mesh文件、ozz的mesh文件导出成引擎能用的antmesh文件。**该库只用在编辑器下**

#### bgfx
对3rd/bgfx以及nuklear ui库的封装。

#### bullet
物理引擎bullet的binding库。

#### cjson

#### clibs

#### clonefunc

#### cppfs

#### crypt
用于生成sha1加密的库

#### debugger

#### filewatch

#### hierarchy
ozz-animation模块的binding库，其中，hierarchy是用于层次结构和骨骼，animation是用于动画

#### iup
主程序iup

#### libimobiledevice

#### lodepng
png库。

#### lsocket

#### lua
lua库。所有的lua binding相关的库都依赖这个库

#### math3d
数学库。分两部分，math3d.cpp文件下面，实现的是一个栈式结构数学库，baselib.cpp下面，实现的是能够转义到c里面运行的相关数学函数

#### memoryfile
内存文件库

#### protocol

#### redirectfd
重定向标准输出的库

#### remotedebug

#### subprocess

#### terrain
地形库

#### thread

#### winfile
实现window下，lfs功能的库

