## debugserver

- debugserver文件目前都存放于ant/libs/debugserver目录下, 代码实现的功能主要是将原先单独的fileserver界面整合到编辑器当中

- debugserver的目前与其他功能放在不同的世界(world)中, 创建的时间在主世界后, 代码在libs/editor/control/mainmenu.lua中, 默认是注释掉

- debugserver除了文件服务器模块, 还包括文件监听模块, 以及虚拟文件系统, log系统等等. 
	- 文件监听模块是filewatch_system, 用于监听指定目录是否有文件变更; 若有变更则需要更新虚拟文件系统.目前监听的文件目录只包括ant/libs, 若要监听其他文件目录需要进行添加
	- 虚拟文件系统是vfs_repo_system, 用于管理文件. 源代码在ant/libs/vfsrepo以及ant/runtime/core当中
	- log系统则是用于将客户端的输出打印在编辑器的log栏里面, 客户端的log通过网络获取, 然后通过redirectfd转发到对应的log栏显示


- 相对应的客户端放在ant/runtime下, 目前包括iOS和Windows版本. Windows版本的客户端主要作用目前还是模拟iOS版本, 所以结构和iOS版本类似, 调用的代码也和iOS客户端一样, 放在ant/runtime/ios/ant_ios/fw中

- 如果需要使用
	- 打开服务端:
		- 首先需要在mainmenu.lua中的openMap函数打开被注释掉的server_main代码, 以及runFile函数被注释掉的代码.
		- 然后打开编辑器, 打开一个地图文件
		- 等待一定的时间, 第一次运行文件系统需要初始化, 时间可能会稍微久一点
	- 打开客户端:
		- iOS的话是一个app, Windows端则是用iup打开runtime/windows/WindowsMain.lua
		- 服务端成功载入地图后, 点击客户端上的start按钮
	- 然后点击编辑器菜单栏的file栏下的runfile, 选中目标文件运行(目前测试文件是ant/libs/dev/testlua.lua).



- 后续需要改进的东西
	- 目前测试案例比较不全, 复杂场景还没有测试过, 需要找时间去测试其他效果
	- iOS app设计简陋, 需要按照特定的顺序启动
	- 编辑器操作和显示方面还有进一步优化的空间
	- 文件系统管理还可以进一步优化, 减少管理不必要的文件和目录, 可以优化空间和速度

