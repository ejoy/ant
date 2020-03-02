Ant 游戏引擎
=====

### 预编译 dll 在 bin 下，以 submodule 方式引用。第一次需要用以下指令初始化：

> git submodule update --init

### 搭建MINGW环境
*由于3rd工程需要make命令，如果在msvc中使用cmake手动生成的话，理论上不需要搭建这个环境*
- 下载msys2：https://www.msys2.org/；
- 下载完后安装，安装完成后（假设安装目录在d:/msys64)，在d:/msys64/etc/pacman.d下，可以见到：mirrorlist.mingw32/mirrorlist.mingw64/mirrorlist.msys。其中mingw32对应32位的mingw，而mingw64对应64位的mingw。而msys对应的是两者。次序分别是ming32/ming64，然后才是msys。添加下面的镜像：Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/x86_64/；
- 需要安装：gcc/make/cmake至少这三个命令，需要注意的是，使用pacman安装某些包，如gcc和cmake，都需要指定到mingw（因为msys下，有gnu的包）。gcc：mingw-w64-x86_64-gcc cmake： mingw-w64-x86_64-cmake。（经验就是，gun下的包，都需要添加'mingw-w64-x86_64-'后带对应的包名）；


### 编译
工程分为三部分：
- 3rd为引用的第三方库的目录所在；
- clibs为引擎使用到的c模块所在的位置，会使用3rd中的第三方库；
- engine为纯lua的库，会使用clibs编译的c模块；

#### 编译3rd

> $cd 3rd  
> $make init MODE=debug #PLAT=mingw/msvc/osx/ios, MODE默认是release  
> $make all MODE=debug -j8	#PLAT=xxx, msvc目前无法直接通过命令行编译  

此外，如果要重新生成指定3rd中的库可以：
> $cd 3rd  
> $make *$(project)*_init PLAT=ios MODE=debug	#初始化指定的project，如：make bgfx_init，此外， PLAT宏依然可用  
> $make *$(project)*_make	#生成指定的project，如：make bgfx_make  

生成的工程文件会在：
> 3rd/build/*$(project)*/*(mingw|OSX|msvc)*	#分别对应不同平台（通过PLAT宏来指定）

#### 编译clibs  

> $cd clibs  
> $make -jn BIN=../bin	#其中make *$(foldername)*可以编译其中指定文件夹下的binding库。其中BIN的宏用于指定编译后的lib存放的位置  

如果需要编译msvc，那么直接打开：
> $(antfolder)/projects/msvc/ant.sln  

##### OSX/iOS编译

*OSX平台下面的文件名称与window下面的文件名称一致，即动态库的后缀仍然是dll，可执行文件的后缀仍然是ant.exe*

> cd 3rd  
> make init PLAT=osx MODE=debug  
> make all PLAT=osx MODE=debug -j8  
> cd ../clibs/ant  
> make ant.exe PLAT=osx MODE=debug  
> cd ../clibs/filewatch  
> make PLAT=osx MODE=debug && cp filewatch.dll ..  

osx运行的环境就算编译成功了。而osx主要用于运行fileserver。

iOS:
> cd 3rd  
> make init PLAT=ios MODE=debug  
> make all PLAT=ios MODE=debug -j8  
> cd ../clibs/ant  
> make PLAT=ios MODE=debug -j8  

编译成功后，使用xcode打开runtime/ios/ant.xcodeproj工程后，编译运行即可

### 运行
目前基于包管理，每个包是可以理解为一个工程，而引擎中默认的包存放在$(antfolder)/packages，默认是都会载入的。
> 需要注意的是，如果$(antfolder)/packages/*packagename*，*packagename*目前下如果没有package.lua文件，会报错。所以不用的包文件夹要及时清理

#### 编辑器模式
> clibs/lua.exe test/imgui/main.lua	#会打开一个场景观察器的UI框架  
> projects/msvc/vs_bin/x64/Debug/lua.exe tools/modelviewer/main.lua --bin=msvc #会使用msvc编译的程序进行启动

#### 使用fileserver运行runtime程序到iOS设备
1. 启动fileserver，OSX和window环境下都能够运行 
> clibs/ant/ant.exe tools/fileserver/main.lua tools/modelviewer  
> 这里的*tools/modelviewer*表示要运行的例子程序

2. 启动proxy连接程序
> clibs/ant/ant.exe tools/fileserver/mobiledevice/proxy.lua

3. 使用xcode，安装ant app到iOS设备上

### 关于ant目录结构
- **bin**：用于存放mingw下的dll
- **libs**：用于存放lua程序必要的lua文件
- **clibs**：存放lua binding的c/c++库
- **packages**：引擎提供的系统包（包与包之间有依赖）
- **projects**：工程相关的目录（目前只用msvc）
- **tools**：引擎相关的工具，实际上目录下的所有文件夹都是相应的包
- **test**：测试文件存放的地方（应该很多例子都跑不起来了）
