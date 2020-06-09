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


### 编译
工程分为三部分：
- 3rd为引用的第三方库的目录所在；
- clibs为引擎使用到的c模块所在的位置，会使用3rd中的第三方库；
- engine为纯lua的库，会使用clibs编译的c模块；

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

#### 运行时库的编译
运行时库的目录位于clibs/ant下，其包括两种形态，如果是iOS/Android的话，需要编译成lib文件；如果是OSX/Window，则需要编译生成出一个ant.exe。原因是，iOS和Android都会被编译紧相应平台的框架下，需要以静态库的形式存在；而OSX/Window则没有这种要求，并且不存在所谓的框架，直接生成可执行文件即可。

##### iOS编译
> cd 3rd  
> make init PLAT=ios MODE=debug  
> make all PLAT=ios MODE=debug -j8  
> cd ../clibs/ant
> make PLAT=ios MODE=debug -j8

这里需要定位到目录：*../clibs/ant*下，该目录用于生成运行时所需要的lib文件

编译成功后，使用xcode打开runtime/ios/ant.xcodeproj工程后，编译运行即可

##### OSX/Window
> cd 3rd
> make init PLAT=osx MODE=debug
> make all PLAT=osx MODE=debug
> cd ../clibs/ant
> make ant.exe PLAT=osx MODE=debug

### 运行
编辑器模式和运行时模式的不同点在于，编辑器模式不需要fileserver的服务，能够实时的修改资源后自动编译等，其只运行在OSX/Window下；而运行时模式并不会在运行的过程中编译资源文件，需要fileserver提供的文件服务，能够运行在OSX/Window/iOS下。

#### 编辑器模式
目前基于包管理，每个包是可以理解为一个工程，而引擎中默认的包存放在$(antfolder)/packages，默认是都会载入的。
> 需要注意的是，如果$(antfolder)/packages/*packagename*，*packagename*目前下如果没有package.lua文件，会报错。所以不用的包文件夹要及时清理
>
>
> #运行一个最简单的示例
> #mingw/OSX
> clibs/lua.exe test/simple/main.lua
> #msvc
> projects/msvc/vs_bin/Debug/lua.exe test/simple/main.lua

#### 使用fileserver运行runtime程序到iOS设备
1. 启动fileserver，OSX和window环境下都能够运行 
> clibs/ant/ant.exe tools/fileserver/main.lua test/simple
> 这里的*tools/modelviewer*表示要运行的例子程序

2. 如果是iOS的话：
> #启动proxy连接程序
> clibs/ant/ant.exe tools/fileserver/mobiledevice/proxy.lua

最后，使用xcode，安装ant app到iOS设备上；

3. 如果是OSX/Window的话：
> clibs/ant/ant.exe test/simple/main.lua

### 关于ant目录结构
- **bin**：用于存放mingw下的dll
- **libs**：用于存放lua程序必要的lua文件
- **clibs**：存放lua binding的c/c++库
- **packages**：引擎提供的系统包（包与包之间有依赖）
- **projects**：工程相关的目录（目前只用msvc）
- **tools**：引擎相关的工具，实际上目录下的所有文件夹都是相应的包
- **test**：测试文件存放的地方
