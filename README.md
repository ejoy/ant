Ant 游戏引擎
=====

### 预编译 dll 在 bin 下，以 submodule 方式引用。第一次需要用以下指令初始化：

> git submodule update --init

### 搭建MINGW环境
- 下载并安装[msys2](https://www.msys2.org/)

- 修改镜像服务器
``` bash
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/i686/" > /etc/pacman.d/mirrorlist.mingw32
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/x86_64/" > /etc/pacman.d/mirrorlist.mingw64
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/msys/\$arch/" > /etc/pacman.d/mirrorlist.msys
```

- 把ming64的路径加到环境变量
``` bash
echo "export PATH=/mingw64/bin:$PATH" >> ~/.bash_profile
```

- 安装gcc/make/cmake
``` bash
pacman -Syu make mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake
```

### 下载FBX2glTF

下载[FBX2glTF](https://github.com/facebookincubator/FBX2glTF/releases),并放到3rd/bin目录下


### 编译
工程分为三部分：
- 3rd为引用的第三方库的目录所在；
- clibs为引擎使用到的c模块所在的位置，会使用3rd中的第三方库；
- engine/packages为纯lua的库，会使用clibs编译的c模块；

#### 编译3rd

``` bash
cd 3rd  
make init MODE=debug/release PLAT=mingw/msvc/osx/ios
make all -j8 MODE=debug/release	PLAT=mingw/msvc/osx/ios
```

也可以单独编译一个项目
``` bash
cd 3rd  
make $(ProjectName)_init MODE=debug/release PLAT=mingw/msvc/osx/ios
make $(ProjectName)_make MODE=debug/release PLAT=mingw/msvc/osx/ios
```
#### 编译clibs  

*OSX平台下面的文件名称与window下面的文件名称一致，即动态库的后缀仍然是dll，可执行文件的后缀仍然是ant.exe*

``` bash
cd clibs  
make -j8 MODE=debug/release
```

如果需要编译msvc，那么直接打开：
> $(antfolder)/projects/msvc/ant.sln  

##### runtime:iOS
``` bash
cd 3rd  
make init PLAT=ios MODE=debug/release
make all -j8 PLAT=ios MODE=debug/release
cd ../clibs/ant
make -j8 PLAT=ios MODE=debug/release
```

这里需要定位到目录：*../clibs/ant*下，该目录用于生成运行时所需要的lib文件

编译成功后，使用xcode打开runtime/ios/ant.xcodeproj工程后，编译运行即可

##### runtime:OSX
``` bash
cd 3rd
make init PLAT=osx MODE=debug
make all PLAT=osx MODE=debug
cd runtime/osx
make
```

### 运行
运行一个最简单的示例
> bin/msvc/debug/lua.exe test/simple/main.lua

### 关于ant目录结构
- **bin**：用于存放dll
- **libs**：用于存放lua程序必要的lua文件
- **clibs**：存放lua binding的c/c++库
- **packages**：引擎提供的系统包（包与包之间有依赖）
- **projects**：工程相关的目录（目前只用msvc）
- **tools**：引擎相关的工具，实际上目录下的所有文件夹都是相应的包
- **test**：测试文件存放的地方
