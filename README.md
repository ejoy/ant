Ant 游戏引擎
=====

### 预编译 dll 在 bin 下，以 submodule 方式引用。第一次需要用以下指令初始化：

> git submodule update --init

### 编译
工程分为三部分：
- 3rd为引用的第三方库的目录所在；
- clibs为引擎使用到的c模块所在的位置，会使用3rd中的第三方库；
- libs为纯lua的库，会使用clibs编译的c模块；

编译3rd

> $cd 3rd  
> $make init MP=-j8	#PLAT=msvc，表示初始化msvc的工程，默认不填会初始化makefile，其中：MP=-j8，表示使用多进程进行make，-j8表示用8个线程
> $make all		#PLAT=msvc，不可用，编译msvc的工程可以直接双击3rd/build_msvc_all.bat文件

此外，如果要重新生成指定3rd中的库可以：
> $cd 3rd
> $make *$(project)*_init 	#初始化指定的project，如：make bgfx_init，此外， PLAT宏依然可用
> $make *$(project)*_make	#生成指定的project，如：make bgfx_make

生成的工程文件会在：
> 3rd/build/*$(project)*/*(mingw|OSX|msvc)*	#分别对应不同平台（通过PLAT宏来指定）

编译clibs  

> $cd clibs
> $make -jn BIN=../bin	#其中make *$(foldername)*可以编译其中指定文件夹下的binding库。其中BIN的宏用于指定编译后的lib存放的位置

如果需要编译msvc，那么直接打开：
> $(antfolder)/projects/msvc/ant.sln
文件直接编译即可

### 运行
目前基于包管理，每个包是可以理解为一个工程，而引擎中默认的包存放在$(antfolder)/packages，默认是都会载入的。
> 需要注意的是，如果$(antfolder)/packages/*packagename*，*packagename*目前下如果没有package.lua文件，会报错。所以不用的包文件夹要及时清理

#### 运行的例子
> bin/lua.exe test/samples/editorlauncher/main.lua	#会打开一个场景观察器的UI框架
> projects/msvc/vs_bin/x64/Debug/lua.exe tools/modelviewer/main.lua with-msvc #会使用msvc编译的程序进行启动

### 关于ant目录结构
- **bin**：用于存放mingw下的dll
- **libs**：用于存放lua程序必要的lua文件
- **clibs**：存放lua binding的c/c++库
- **packages**：引擎提供的系统包（包与包之间有依赖）
- **projects**：工程相关的目录（目前只用msvc）
- **tools**：引擎相关的工具，实际上目录下的所有文件夹都是相应的包
- **test**：测试文件存放的地方（应该很多例子都跑不起来了）