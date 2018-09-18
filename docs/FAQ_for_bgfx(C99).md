FAQ for bgfx
=============

阅读bgfx源代码策略
-------------------

源文件中bgfx_p.h对于使用bgfx的价值极大。

源文件中的renderer.h中的setPredefined函数设置了bgfx内置的uniform。

也就是bgfx提供的类似bgfx_set_transform使用的uniform。

renderer.gl.cpp的7016行左右的

            viewState.setPredefined<1>(this, view, eye, program, _render, draw);

设置了这些预定义的uniform。

bgfx_submit函数实际上是

                      void EncoderImpl::submit(ViewId _id, ProgramHandle _program, OcclusionQueryHandle _occlusionQuery, int32_t _depth, bool _preserveState)

这个函数的实现位于bgfx.cpp中，它将当前的一些设置添加到frame中，但不进行实际的渲染。

对于bgfx的渲染细节可以查看renderer_gl.cpp的submit函数(这个submit函数是由bgfx的API函数frame调用的)。

基本我们bgfx的API设置的所有渲染信息在这里都被真正提交，从这里可以看出这些信息是如何被使用。

renderer_gl.cpp的ProgramGL::create和ShaderGL::create函数是真正的着色器创建代码。

bgfx的绘制调用排序
----------------------------------------

bgfx的绘制调用排序是使用SortKey完成的(SortKey的定义和代码在bgfx_ph.h中)。

touch(ViewId id)函数和touch(0)
-----------------------------------------

touch函数实际上就是一个空的submit调用。
touch(0)实际上就是submit(0,BGFX_INVALID_HANDLE)

submit和frame的关系
-----------------------------

frame由0个或1个或多个submit提交的信息构成。可以这样认为frame是一个submit的集合。

setTransform函数
----------------------------

setTransform函数设置的矩阵是放在frame中的，当前绘图调用(一次submit)存储了一个指向它的索引。

相关代码如下:

                        uint32_t setTransform(const void* _mtx, uint16_t _num)
		{
			m_draw.m_startMatrix = m_frame->m_frameCache.m_matrixCache.add(_mtx, _num);
			m_draw.m_numMatrices = _num;

			return m_draw.m_startMatrix;
		}
                        
在renderer_gl.cpp中(也就是调用frame函数时)使用了它，相关代码如下:

                        case PredefinedUniform::Model:
                        {
		            const Matrix4& model = frameCache.m_matrixCache.m_cache[_draw.m_startMatrix];
			_renderer->setShaderUniform4x4f(flags
			, predefined.m_loc
			, model.un.val
			, bx::uint32_min(_draw.m_numMatrices*mtxRegs, predefined.m_count)
			);
		}
		            break;

编译bgfx官方的shaderc工具
-----------------------------

安装好编译工具链后进入bgfx的源代码目录执行make shaderc。

如果提示信息缺少yacc和lex，使用pacman -S bison flex来安装yacc和lex。

如果还无法编译成功的话运行bgfx/3rdparty/glsl-optimizer/generateParsers.sh脚本

然后在bgfx目录下运行make shaderc。

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
