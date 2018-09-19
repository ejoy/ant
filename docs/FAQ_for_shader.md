FAQ for shader
=========================

编译shader的GUI工具
---------------------

可以通过下面的代码来运行编译shader的GUI工具

        bin/iup.exe tools/shaderc.lua

编译bgfx官方的shaderc工具
------------------------------

安装好编译工具链后进入bgfx的源代码目录执行make shaderc。

如果提示信息缺少yacc和lex，使用pacman -S bison flex来安装yacc和lex。

如果还无法编译成功的话运行bgfx/3rdparty/glsl-optimizer/generateParsers.sh脚本

然后在bgfx目录下运行make shaderc。

bgfx官方shaderc工具的使用说明
-------------------------------

shaderc的命令行参数说明:

	Usage: shaderc -f <in> -o <out> --type <v/f> --platform <platform>

	Options:
  	-h, --help                    显示帮助信息.
  	-v, --version                 显示shaderc版本信息.
  	-f <file path>                待编译文件路径.
  	-i <include path>             包含路径 (对于多个包含路径，可以多次使用-i参数来指定它们).
  	-o <file path>                编译后生成的文件路径.
      		--bin2c <file path>       生成的C头文件路径.
      		--depends                 生成Makefile风格的依赖文件信息(Generate makefile style depends file).
      		--platform <platform>     目标平台.
           		android
           		asm.js
           		ios
           		linux
           		nacl
           		osx
           		windows
      		--preprocess              仅进行预处理.
      		--define <defines>        添加define宏定义(分号分割).
      		--raw                     不对shader进行处理，不进行预处理，不进行glsl优化(仅支持GLSL).
      		--type <type>             shader类型(vertex, fragment).
      		--varyingdef <file path>  varying.def.sc文件路径.
      		--verbose                 Verbose.

	Options (DX9 and DX11 only):

      		--debug                   调试信息(Debug information).
      		--disasm                  反汇编shader.
  	-p, --profile <profile>       Shader model (f.e. ps_3_0).
  	-O <level>                    优化级别(0, 1, 2, 3).
      		--Werror                  将警告作为错误.

下面介绍如何进行shader的编译。

	./shaderc --platform windows -i ./ -p vs_4_0 -O 3 --type vertex -f test.vs -o vs_test.bin
	./shaderc --platform windows -i ./ -p ps_4_0 -O 3 --type fragment -f test.fs -o fs_test.bin

这里shaderc和我们的shader文件都在当前目录下。

我们使用--platform编译windows平台的shader，使用vs_4_0这一shader model，使用--type指定我们编译的是顶点shader。

使用-f参数指定要编译的shader源文件,使用-o参数指定编译生成的目标文件。

使用-O参数指定使用优化等级3。

由于我们没有使用--varyingdef，它会使用当前目录下的varying.def.sc文件。


(1)对于 **uniform** 不能使用 **bool/int** ，所有 **uniform** 都必须是 **float** 类型。

(2) **attribute** 和 **varying** 只能在 **main()** 中被访问。

(3)必须使用 **SAMPLER2D/3D/CUBE** 宏来代替 **sampler2D/3D/Cube** 。

(4)必须使用 **vec3/3/4_splat(<value>)** 来代替 **vec2/3/4(value)**。

(5)必须使用 **varying.def.sc** 来定义输入输出和精度，不能使用 **attribute/in** 和 **varying/in/out** 来做这件事。

(6) **$input/$output** 必须出现在shader的开始处。

bgfx提供了这些宏来帮助我们编写shader：

https://github.com/bkaradzic/bgfx/blob/master/src/bgfx_shader.sh

这里提供完整的工程文件：

shader编译的工程文件：

https://github.com/fangcun010/shadercTest

使用上面编译的shader编写的使用BGFX绘制红色三角形的工程文件(VS2017)：

https://github.com/fangcun010/BgfxTriangle

预定义uniform的一些说明
------------------------

bgfx提供的一些API是通过uniform的方式实现的，比如bgfx_set_transform。

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
