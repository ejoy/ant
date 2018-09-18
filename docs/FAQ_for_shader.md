FAQ for shader
=========================

编译shader的GUI工具
---------------------

可以通过下面的代码来运行编译shader的GUI工具

        bin/iup.exe tools/shaderc.lua
 
预定义uniform的一些说明
------------------------

bgfx提供的一些API是通过uniform的方式实现的，比如bgfx_set_transform

bgfx有下面这些预定义的uniform

                ViewRect                        "u_viewRect"
                ViewTexel                       "u_viewTexel"
                View                            "u_view"
                InvView                         "u_invView"
                Proj                            "u_proj"
                InvProj                         "u_invProj"
                ViewProj                        "u_viewProj"
                InvViewProj                     "u_invViewProj"
                Model                           "u_model"
                ModelView                       "u_modelView"
                ModelViewProj                   "u_modelViewProj"
                AlphaRef                        "u_alphaRef4"

通过阅读bgfx的OpenGL后端实现，可以发现对于一个着色器程序，如果某个预定义的uniform没有被使用(两种情况:

(1)shader中没有定义这个uniform

(2)shader中定义了这个uniform但是在shader中没有代码使用它)

那么它就不会被bgfx认为是存在的(bgfx的OpenGL后端代码中使用glGetActiveUniform来进行预定义uniform的检测)。

简单说就是如果我们完全不用bgfx提供的shader，自己编写shader可以像使用OpenGL可编程管线一样使用bgfx，

但是这样就不能使用bgfx提供的一些便捷API。

如果需要使用bgfx的API，可以在自己的shader中定义它们，bgfx的相应API就会起作用。
需要注意的是bgfx的API自己维护了设置数据的状态，比如bgfx_set_view_transform并没有设置着色器程序的uniform，
而是把它存进view的state中，在frame时才真正进行了uniform的设置。

预定义属性
-------------------

bgfx使用了一些预定义的属性，具体如下：

	static const char* s_attribName[] =
	{
		"a_position",
		"a_normal",
		"a_tangent",
		"a_bitangent",
		"a_color0",
		"a_color1",
		"a_color2",
		"a_color3",
		"a_indices",
		"a_weight",
		"a_texcoord0",
		"a_texcoord1",
		"a_texcoord2",
		"a_texcoord3",
		"a_texcoord4",
		"a_texcoord5",
		"a_texcoord6",
		"a_texcoord7",
	};

我们使用bgfx的API设置的一些信息比如顶点位置信息，法线信息实际上在shader中是通过它们访问的。
