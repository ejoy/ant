Ant 游戏引擎
=====

### 更新并初始化第三方库：

> git submodule update --init

### 搭建编译环境

#### MSVC
- 安装Visual Studio 2019+

- 下载并安装[cmake](https://cmake.org/download/)

#### MINGW
- 下载并安装[msys2](https://www.msys2.org/)

- 修改镜像服务器
``` bash
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/i686/" > /etc/pacman.d/mirrorlist.mingw32
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/x86_64/" > /etc/pacman.d/mirrorlist.mingw64
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/msys/\$arch/" > /etc/pacman.d/mirrorlist.msys
```

- 把ming64的路径加到环境变量
``` bash
echo "export MINGW=/mingw64" >> ~/.bash_profile
echo "export PATH=\$MINGW/bin:\$PATH" >> ~/.bash_profile
```

- 安装gcc/make/cmake
``` bash
pacman -Syu make mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja
```

#### 关于模型的转换工具
引擎支持直接支持glb（glTF文件的二进制，但不支持二进制的glTF格式）文件格式，需要使用FBX的话，可以使用FBX2glTF工具。

- FBX2glTF
下载[FBX2glTF](https://github.com/facebookincubator/FBX2glTF/releases),并放到3rd/bin目录下
- glTF转glb工具
https://github.com/KhronosGroup/glTF#gltf-tools

### 构建luamake

``` bash
git clone https://github.com/actboy168/luamake
cd luamake
git submodule update --init
.\compile\install.bat (msvc)
./compile/install.sh (mingw/linux/macos)
```

### 编译
工程分为三部分：
- 3rd为引用的第三方库的目录所在；
- clibs为引擎使用到的c模块所在的位置，会使用3rd中的第三方库；
- engine/packages为纯lua的库，会使用clibs编译的c模块；

#### 编译3rd

``` bash
luamake 3rd_init
luamake 3rd_make
```

也可以单独编译一个项目
``` bash
luamake $(ProjectName)_init
luamake $(ProjectName)_make
```

#### 编译editor

``` bash
luamake
```

#### 编译runtime

``` bash
luamake runtime
```

### 运行
运行一个最简单的示例
``` bash
bin/msvc/debug/lua.exe test/simple/main.lua
```

### 关于ant目录结构
- **bin**：用于存放dll
- **libs**：用于存放lua程序必要的lua文件
- **clibs**：存放lua binding的c/c++库
- **packages**：引擎提供的系统包（包与包之间有依赖）
- **projects**：工程相关的目录（目前只用msvc）
- **tools**：引擎相关的工具，实际上目录下的所有文件夹都是相应的包
- **test**：测试文件存放的地方
