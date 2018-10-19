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

传统 Unix 虚拟环境

提供 MinGW 环境，bash shell控制，packman 软件包安装等工具
	

下载地址：  www.msys2.org 

下载安装包：msys2-x86_64-20161025.exe
	
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

		
S5: pacman -S make  make没有默认安装，需要执行这个命令完成安装

pacman -S git   同上 

pacman -S svn   同上

pacman -S mingw-w64-x86_64-cmake 同上   // assimp 目前是编译需要  
		
	
辅助配置:

pacman 中国镜像,速度较快

在 D:/msys64/etc/pacman.d/mirrorlist.msys         // 添加，最前面

Server = http://mirrors.aliyun.com/archlinux/     // ALI mirror 
        
	
+..到此Unix 仿真环境，对应 gcc,make,cmake,git,svn 等工具应都安装完成.
	
## 2.工作目录组织 ##
  
	构建后的目录样例	
    |-D:/WORK
		|- ant         	    //ant  引擎目录
			|--assets   	//ant  引擎资源目录 
			|- libs      	//ant  引擎通用源代码
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
		|- ant3rd
			|- assimp          // 3D模型文件库
			|- bgfx            // bgfx 渲染引擎
			|- bimg            // bgfx 的图像库
			|- bx              // bgfx 的工具,包括编译工程生成工具
			|- cd
			|- freetype
			|- iup
			|- ozz-animation
			|- zlib

		|------------------------------	 
		| 以下可略，使用编译库即可
		|- iup    iup  ui 工具库
		|- co
		|- im
		|- lua53  
	  
	  
## 下载及构建工作环境
     以 D：盘为例	  
     在 D：盘建立 D:/WORK 目录，作为 ant  等项目的存放目录 
		
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
	 
        +..ant 工程下载和配置完成
		
	 S2: 第三方库配置
	 	 第三方库我们进行了统一管理, 放在公司使用的GitBucket上
	 	 登陆https://gz-tea.ejoy.com, 并登陆账号
	 	 找到Ant/ant3rd的repository
	 	 或者直接git clone https://gz-tea.ejoy.com/git/Ant/ant3rd.git到ant的同级目录下,如最开始的目录样例所示
	 	 运行命令:
	 	 $git submodule update --init	//更新子仓库
	 	 $make init						//构建各个子项目工程
	 	 $make all 						//构建所有子项目
	 	 
	 	 如果成功即完成第三方库配置, 下方是各个库的单独配置方法, 可以跳过

	    ##注意：
		 -所有 git clone 下载的文件，可能会自动转换成Windows(CR/LF) 模式
		  这在同步项目仓库时会有修改警告,需要执行 $git checkout .
		  进行同步转换文本格式，以保留Unix(LF) 模式

	 S3: 编译ant/clibs 
	    cd /d/work/ant/clibs
		make 执行编译
		当遇到不存在的dll，进入对用的子目录，单独对该子功能make
	
	 
		#-------- 一些makefile 配置注意点 ----------	 
		# 编译 clibs/bgfx 注意事项
		# 针对开源引擎 bgfx 的存储目录进行配置
		
		#--例子1： bgfx 存放在非 ant 同级目录
		bgfx 保存在 D:/Gits/bgfx 则修改 D://work/ant/clibs/bgfx/makefile
		BGFXROOT = ../../../../Gits/bgfx

		#--例子2： bgfx 存放在 ant 同级目录 
		# Use make BGFXROOT=your_bgfx_path
		BGFXROOT = ../../..   //ant/clibs/bgfx 
        
		/*
			BGFXSRC = $(BGFXROOT)/bgfx
			BXSRC = $(BGFXROOT)/bx
			BIMGSRC = $(BGFXROOT)/bimg
			LUAINC = -I ../lua
			LUALIB = -L ../lua -llua53--
			ODIR = o

			CC= gcc
			CXX = g++
			CFLAGS = -O2 -Wall

			mingw : bgfx.dll
		*/

	 
## 第三方库单独运行测试及编译：
	目录假设在D:/gits
    S1：编译 bgfx 
    	下载 bgfx 引擎 
		cd /d/gits 
		//clone bgfx 
		$git clone http://github.com/bkaradzic/bgfx
		//clone bx
		$git clone https://github.com/bkaradzic/bx
		//clone bimg
		$git clone https://github.com/bkaradzic/bimg
		 
	    cd   /d/gits/bgfx 
		make 产生工程文件
		make mingw-gcc-release64 编译对应的版本
		
	S2: 编译 assimp 
	    cd  /d/gits/assimp 
		下载 assimp 
		$git clone https://github.com/assimp/assimp
	
		Assimp 缺少 RT 库文件,注释掉 FIND_PACKAGE(RT_QUIET)
		修改 assimp/code/CMakelists.txt
		注释 #FIND_PACKAGE(RT QUIET)

		//生成工程文件，屏蔽 IFC 格式（建筑方面文件）
		// -Wa,-mbig-obj
		//mkdir build 
		//cd build
		//cmake -D ASSIMP_BUILD_IFC_IMPORTER=OFF -G "Unix Makefiles" ..
		// 上述创建biuld 目录的方法，会导致revision.h 文件产生在build/revision.h 目录下 
		// 在编译assimp_cmd.rc 文件时，将访问不到 
		
		// 就在assimp 当前目录下执行,简单一致 
		cmake -D ASSIMP_BUILD_IFC_IMPORTER=OFF -G "Unix Makefiles" .
		make clean
		make 
		make -j8  编译 
		
		
		编译 contrib (略)
		conrib/cmakelist.txt 
		添加 cmake_minimum_required( VERSION 2.6 )

	3.VC 环境
		https://www.visualstudio.com/zh-hans 下载 Community 社区版本即可

		
		
[
