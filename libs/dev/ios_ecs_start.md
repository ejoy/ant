## ios_ecs启动

+ iOS端通过USB线和PC通信是通过libimobiledevice来建立连接的,因此在PC上需要编译对应的dll库, 这几个库都放到了ant3rd中,需要同步一下
	+ **libimobiledevice:** git clone https://github.com/libimobiledevice/libimobiledevice.git
	+ **libplist:** git clone https://github.com/libimobiledevice/libplist.git
	+ **libusbmuxd:** git clone https://github.com/libimobiledevice/libusbmuxd.git
	+ 将这三个库拉下来编译
		+ ./autogen.sh
		+ make
		+ sudo make install
	+ 结果会保存在各个库文件目录下的src/.libs中
	+ 将上面三个库编译完成后,编译ant/clibs/libimobiledevice
		
+ 另外还有一个库需要编译,是用于png格式encode和decode的库lodepng,放在ant/clib/lodepng中

**至此,需要的第三方库就编译完成了**

在运行前,目前需要手动调整一些东西,后续会进行调整和优化
+ 在libs/scene/util.lua中,需要利用asset.insert_searchdir()添加本地资源目录的路径

+ 所有用到的资源.material文件,如果shader是使用文本文件.sc格式的,需要改用bin格式的文件,即删掉".sc".如果该shader没有.bin格式的需要利用shaderc编译iOS格式. 编译好的文件放在shader资源下的essl目录. 
	+ 目前在Ant/assets仓库里面上传的shader包括:
	+ mesh/vs_mesh_bump; mesh/fs_mesh_bumpex
	+ simple/light_bulb
	+ terrain
	+ ui	
	+ 其他的shader暂时需要自己编译
+ 其他资源也需要注意路径,搜索会从上面添加的资源路径搜索(目前就是地形那块我把资源路径前面的assets/build都去除了,相关资源也修改了)


+ 使用流程
	+ 下载并且安装iTunes
	+ 利用usb线连接iOS设备和PC
	+ 在PC端利用iup打开服务器窗口: bin/iup libs/dev/Server/server_ui.lua
	+ 打开iOS设备上的fileserver app
	+ 点击**devices**框中的udid(*很长的一串字符串,后续会改成iOS设备的名称*),然后点击右下方三个按钮中的**connect**
	+ 如果成功,会在**connected**框中显示设备的udid
	+ 点击左下角两个按钮中的**select**按钮,设定工程的路径,需要设定在**ant/libs**下
		+ *由于目前还加上记录上次修改的优化,所以需要每次都设定.觉得麻烦的话可以先在server\_ui.lua中将default\_proj\_dir设定为你使用的目录*
	+ 设定完成后,点击**run file**按钮, 选中ant/libs/ios_main.lua,等待场景加载
	+ 若想要查看截图,点击右下方三个按钮的最右边的按钮**open/close simpad**,会把手机端的画面截图传回来.目前截图的频率是每秒截图一次

+ 自定义运行脚本
	+ 如果不想使用ios_main.lua作为测试脚本的话,可以自定义脚本.自定义脚本需要是一个table,并返回几个函数包括:
		+ init(window_handle, fbw, fbh, app_dir, bundle_dir)初始化函数
			+ window_handle是iOS设备屏幕的句柄
			+ fbw,fbh是屏幕的宽度和高度
			+ app_dir是fileserver app的地址
			+ bundle_dir是fileserver沙盒的地址,*这两个地址一般不需要使用*.
		+ mainloop()更新函数
		+ input(msg_queue)输入处理函数
			+ msg_queue是一个table,其中的每个元素也是一个table,保存的是设备传入的信息.
			+ 每个信息元素包含以下内容:
				+ msg: 触碰消息的种类,包括"begin","move","end"以及"cancel"
				+ x/y: 触碰消息的位置
		+ terminate()终止函数,用于清理环境


+ 后续优化
	+ 文件系统针对已经cache的文件向server定时检查,并且更新
	+ 优化exist检查,避免同一个文件重复去server做exist检查的操作,会送出很多消息,也会做很多hash计算.考虑做一个cache把当此运行的所有检查过的文件缓存起来
	+ 将上一次的状态缓存起来,包括工程目录的路径,自动打开上一次打开的项目等等
	+ server上指定resource_dir,用于assets的搜寻路径
	

+ bug
	+ cppfs使用到了c++17的experimental/filesystem,在xcode上目前并不支持.所以当前没有开启这项功能,后续要修改打包方式,并解决这个问题

