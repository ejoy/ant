### libs document
每个文件夹下面的util.lua/test.lua 文件有其特殊含义。
- util.lua 通常是用来存放能够服用的代码的地方
- test.lua 通常用来测试对应库，并提供一个基本的使用方法


#### animation
动画相关，包含动画的system、CPU蒙皮的system及component

#### asset
资源加载库。针对不同文件后缀进行自定义加载

#### common
存放通用的代码以及框架配置文件（config.lua）

#### debugger

#### debugserver

#### dev

#### ecs
ECS框架的主要文件

#### editor
编辑器相关的文件，包括对应的ECS系统

#### filesystem
文件系统以及一个路径库（path.lua）

#### fw

#### inputmgr
输入管理器，用于将外部的时间转化为内部能够检测的消息

#### iosys

#### lanes

#### math
数学相关库，用lua实现

#### modelloader
模型数据载入库。能够读取经过转换后的antmesh的文件（这种文件都是通过fbx等转换过来。例如，bgfx和ozz下定义的模型格式都可以转换成antmesh的格式，使用antmeshloader.lua能够读取antmesh文件）

#### packfile
用于将特定文件在加载时进行转换后读取。如shader下的.sc文件，会在读取的时候，先将sc文件编译为bin文件，然后读取。故，填写shader路径时，不应该带上具体的后缀sc，因为框架会尝试先读取同名的.lk文件，然后在lk文件中找到真正需要编译的sc文件。如，line/vs_line，表示的是，使用assets/shaders/src/line/vs_line.lk文件中的src_path指定的文件进行编译。此外，除了shader文件外，模型文件也会进行转换，转换为antmesh文件。转换/编译后的文件会放在根目录下的cache文件夹下。


#### render
渲染相关。如camera，light等

#### scene
场景相关。如cull和filter（即提取具体操作需要图元，如render是一种，shadow是一种等）

#### serialize
序列化相关

#### tested

#### timer
时间相关的system和component。引擎中需要用到的时间，都应该通过这里定义的timer component来获取

#### vfsrepo
虚拟文件系统。能够将制定的文件夹下的所有资源进行hash，然后通过路径获取制定的文件。

#### XXX main.lua
表示的是某个系统的入口文件
