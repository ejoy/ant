# 结构

本系统采用的是C/S结构

## Client端
Client端可以发送指令给Server端,实现不同的需求.

目前的指令包括:

- LIST: 传入一个路径,服务器返回该路径下的所有文件和目录名称.若路径不合法则会返回空
- GET: 传入文件名称和文件hash值(可选),获取Server上该文件, 若Server上没有该文件则什么都不返回. 若传入hash值,则会对Server上的对应文件计算hash,并和client传入的hash比较, 若相同则不返回文件, 不相同则返回Server上的文件
- EXIST: 传入文件名称和文件hash值(可选),判断Server上是否存在相同的文件, 返回结果true或者false
- REQUIRE: 和GET类似,不过主要是针对Lua文件.从Server上获取并保存到内存当中,会根据Client的package.path针对性的搜索多个路径,以后会考虑合并
- SCREENSHOT: 一般是由Server发起，要求Client传回当前的截屏，Client返回数据时也使用SCREENSHOT指令告诉Server这是截屏数据

Client端分为逻辑线程和IO线程, 通过lanes模块生成IO线程, 利用linda object在两个线程中利用消息交互

- 逻辑线程主要管理的是界面操作,交互等方面. 目前可以用过iup搭建了一个小窗口, 测试指令的效果
- IO线程负责和Server通讯, 接受逻辑线程通过linda传来的消息,发送对应的指令给Server; 接受并处理Server传输过来的指令和数据

目前Client端由于版本控制,即本地可能会有不同版本的相同路径的文件,因此并没有按照常规方式存储文件, 而是内部实现了一套文件映射系统, 改文件系统主要包括以下几个table:

- id table: 保存文件目录的信息, key是文件目录的id, root的id为0; value是另外一个table, 这个table里面保存着该目录下的所有文件和目录,我暂时称为dir table
- dir table: 属于id table的value. dir table的key是文件名, 代表id table对应文件目录下的一个子目录和文件的名称; value是子目录和文件的映射id. 如果映射id是一个hash值的话, 表示这个名称对应的是一个文件, 会在下面的file table中查找对应的真实路径; 如果映射id是一个普通数字的话, 代表这个名称对应的是一个子目录, 可以在id table中查找对应的信息
- file table: 存放文件的实际位置. key是文件的hash值, value是文件的实际名称和路径

**这里所有的hash值计算方法都是采用的sha1**

**另外, dir table中的路径其实是虚拟的路径, 也就是Server上文件存储的路径. client端由于版本控制无法使用Server相同的路径格式. client端文件名称实际上是对应文件文件的hash值,存放在对应hash值前三位的目录下(为了防止一个文件目录下文件过多的情况产生)**

目前项目通过dir.txt和file.txt存储上面几个table, dir.txt存放的是id table和dir table; file.txt存放的是file table

****

## Server端

Server端接收Client端传来的指令,返回对应指令和数据, 包括:

- DIR: 针对Client的LIST指令, 返回指定文件目录下文件和子目录的名称, 包括路径, 传送角度, 以及文件名
- EXIST_CHECK: 针对Client的EXIST指令, 若文件存在则返回true, 不存在则返回false
- FILE: 针对Client的GET指令, 返回文件数据. 由于每个数据包的大小不会超过64k, 因此对体积比较大的文件会采取分包的措施. 返回的包括路径, 文件hash值, 传送进度以及文件数据
- ERROR：一般用于返回错误信息
- RUN：命令Client运行某文件，一般是入口脚本，如果Client本地没有该脚本，会尝试在Server上找
- SCREENSHOT：命令Client截屏并返回，Client返回时也会使用SCREENSHOT指令

## iOS
和iOS端通讯需要libimobiledevice库的支持, 需要下载iTunes
另外还需要编译以下三个库的dll, 编译libimobiledevicelua.dll, cpp文件放在LuaBind下
https://github.com/libimobiledevice/libusbmuxd.git
https://github.com/libimobiledevice/libimobiledevice.git
https://github.com/libimobiledevice/libplist.git