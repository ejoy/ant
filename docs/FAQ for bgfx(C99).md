FAQ for bgfx
=============

bgfx调式策略
------------------------
bgfx向debugger输出了很多调试信息，遇到莫名的问题，查看debugger的效率会高很多。
bgfx输出错误信息使用的是bx的debugOutput函数(位于bx\src\debug.cpp中)，在里面使用条件编译根据平台选择合适的输出途径，
在windows下使用的是Windows API函数OutputDebugString。

bgfx提供了回调来设置输出调试信息，所以我们也可以通过设置这个回调来获取bgfx的报错信息。

使用bgfx_create_shader函数程序崩溃
----------------------------------

bgfx_create_shader接受的shader类型依赖于指定的渲染器，如果指定了OpenGL为渲染器就不能使用DX的，bgfx_create_shader接受的参数实际为特定渲染器的特定编译后的二进制格式。
指定渲染器使用bgfx_init函数进行，设置参数变量的type为指定渲染器即可。
