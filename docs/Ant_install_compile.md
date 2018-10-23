<!-- TOC -->

- [开发环境安装](#开发环境安装)
    - [1.MSys2 安装](#1msys2-安装)
    - [2.工作目录组织](#2工作目录组织)
    - [下载及构建工作环境](#下载及构建工作环境)
    - [第三方库单独运行测试及编译：](#第三方库单独运行测试及编译)

<!-- /TOC -->


	ANT Project 开发环境安装及编译配置记录
	-提供给开发同学对类Unix环境的帮助熟悉
		.开发环境安装配置流程
		.工作目录建议组织
		.下载工具,源码仓库及对应的地址,版本
		.编译 , 配置修改
		.运行测试 
  
  
  
# 开发环境安装 #

## 1.MSys2 安装 ##

传统 Unix 虚拟环境，
提供 MinGW 环境，bash shell控制，packman 软件包安装等工具
	

下载地址：  
> www.msys2.org  
> msys2-x86_64-20161025.exe
	
S1: $执行 msys2-x86_64-20161025.exe ，选择安装目录

	例如：C:/msys64 或 D:/msys64 
		
	Windows/任务导航/Msys2 msys ，建立快捷桌面，方便使用

	$执行桌面应用 msys2 msys ，进入msys shell
	
S2: $执行 pacman -Syu，同步更新 mingw 等软件包

	msys2-runtime 与 catgets 有冲突？ ！！  
	按提示安装，若有冲突出现，关闭重启 msys2 msys 再次执行  
	pacman -Syu 即可。
	 
	
S3: $执行 pacman -S mingw-w64-x86_64-gcc 安装统一版本号的gcc  

S4: mingw 的访问的配置 

	打开 D:/MSys64/home/ejoy/.bash_profile

	export MINGW=/mingw64

	export PATH=$MINGW/bin:$PATH

		
S5:  

	$pacman -S make  
	$pacman -S git   
	$pacman -S svn   
	$pacman -S mingw-w64-x86_64-cmake 
> 目前gcc使用的是7.3版本，支持C++17
	
辅助配置:

	pacman 中国镜像,速度较快  
	在 D:/msys64/etc/pacman.d/mirrorlist.msys         // 添加，最前面

	Server = http://mirrors.aliyun.com/archlinux/     // ALI mirror 
        
## 2.工作目录组织 ##
  
	构建后的目录样例	
    |-D:/WORK
		|- ant         	    //ant  引擎目录
			|--assets   	//ant  引擎资源目录 
			|- libs      	//ant  引擎通用源代码，具体文件夹下的内容是干什么用的，应该查看libs/libs_doc.md文件
			|- docs         //ant  工程文档
			|- tools    	//ant  config 配置工具，shader 编译器
			|- test         //ant  测试程序
			|- clibs    	//ant  的针对 bgfx 等支撑库 binding 工程,源代码,编译目标库
				|- assimp-lua     	//assimp lua bingding
				|- crypt          	//加密   组件 
				|- lsocket        	//socket 组件
				|- lanes          	
				|- math3d         	//lua 	组件数学库
				|- redirectfd		
				|- remotedebug		
				|- memoryfile     	
				|- winfile        	
				|- iup      	  	//iup 库	
				|- lua            	//lua53 
			|- 3rd
				|- assimp          // 3D模型文件库
				|- bgfx            // bgfx 渲染引擎
				|- bimg            // bgfx 的图像库
				|- bx              // bgfx 的工具,包括编译工程生成工具
				|- cd
				|- freetype
				|- iup
				|- ozz-animation
				|- zlib
				|- glm			  // 通用的c++数学库，使用方式与GLSL类似

	clibs下的库都都会依赖clibs/lua，因为放在clibs的库都是lua-binding。而相应的库会依赖ant/3rd下的第三方库
	通常情况下，3rd下的库编译的情况应该很少。
	  
### 下载及构建工作环境
	以 D：盘为例	  
	在 D：盘建立 D:/WORK 目录，作为 ant  等项目的存放目录 

#### MINGW ####
S1: ant 工作目录

	执行 MSys2 MSys桌面快捷,进入控制台
	$cd /d/work
	
	$git clone http://github.com/ejoy/ant
	ant clone 生成 D:/WORK/ant
	
	// lua环境的配置
	$ bin/iup.exe tools/config.lua 执行config 配置
	AntConfig 窗口中填写各项条目对应的 exe 目录 
	lua = D:/Work/ant/clibs/lua/lua.exe 
	shaderc为bgfx官方提供的shader编译器，并不是tools目录下的shaderc.lua
	
	//---------------------------------------
	// (略）以下iup,lua等工具可略，建议使用 ant 目录下bin,clibs 都已经生成的工具版本
	cd /D/WORK
	$svn co  https://svn.code.sf.net/p/iup/iup/trunk/iup iup  获取源码
	$cd iup  进入iup目录克隆iupmingw.git 仓库,增加mingw的iup编译支持
	$git clone https://github.com/cloudwu/iupmingw.git mingw
	//---------------------------------------
		
S2: 第三方库配置

	第三方库我们进行了统一管理, 一部分放在gz-tea的服务器上，一部分在github，具体通过3rd/.gitmodules文件查看
	运行命令:

	$git submodule update --init	//更新子仓库
	$make init						//构建各个子项目工程
	$make all 						//构建所有子项目

	如果成功即完成第三方库配置, 下方是各个库的单独配置方法, 可以跳过
>所有 git clone 下载的文件，可能会自动转换成Windows(CR/LF) 模式。这在同步项目仓库时会有修改警告,需要执行 
> >$git checkout .  
> 进行同步转换文本格式，以保留Unix(LF) 模式

S3: 编译ant/clibs 

	$cd /d/work/ant/clibs
	$make
	当然，make -jn (n表示编译的进程数量)也是可以的

-	clibs/common.mk：定义了大量常用的makefile的宏，在添加新的binding库时，尽量使用已经定义好的宏，方便后续的维护
-	clibs/bgfx/bgfx_define.mk：定义了bgfx的路径和相应的变量

> 目前clibs使用C++17的标准，在不影响代码清晰性的情况下，都可以使用最新的C++语法及其支持的STL库


#### MSVC ####
MSVC的工程位于ant/projects/msvc目录下。由于没有使用类似CMake这类的工程管理工具，所以目前msvc和makefile文件都是手动维护。

版本及配置

	目前使用Mircosoft Visual Studio 2017 社区版（旧的版本不支持）

S1: 打开工程

	通过msvc/ant.sln文件夹即可打开工程	

S2: 添加工程

	添加新的工程，可以使用ant/projects/msvc/proj_template下的ant_dll_proj的工程模板。该工程模板已经进行了相关的设定，如会include lua库的路径，设定编译的*.obj文件位置，编译后的dll及exe文件路径等。

S3: 配合Visual Studio Code使用

	使用VSCode启动MSVC编译的工程，需要在Debug调试页面，添加调试选项。如：
> 	{  
		"name": "launch_vs_debug",  
        "type": "lua",  
        "request": "launch",
		"stopOnEntry": false,        
		"cwd": "${workspaceRoot}",  
		"path": "./?.lua",
		"cpath": "./?.dll;${workspaceRoot}/project/msvc/vs_bin/x64/Debug/?.dll",
		"runtimeArgs": "libs/main.lua",            
		"runtimeExecutable" : "${workspaceRoot}/projects/msvc/vs_bin/x64/Debug/iup.exe",
		"env": {"BIN_PATH" : "projects/msvc/vs_bin/x64/Debug"}   
	},

	其中，runtimeExecutable需要是必须要配置的，env下的BIN_PATH也是必须的，否则工程无法在MSVC编译下的路径中找到对应的C模块

	详细的VSCode可以查看ant/docs/debug_with_vscode.md文件