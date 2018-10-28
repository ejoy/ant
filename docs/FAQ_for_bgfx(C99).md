<!-- TOC -->

- [1. FAQ for bgfx](#1-faq-for-bgfx)
    - [1.1. 阅读bgfx源代码策略](#11-阅读bgfx源代码策略)
    - [1.2. 多个View的绘制顺序](#12-多个view的绘制顺序)
    - [1.3. bgfx的绘制调用排序](#13-bgfx的绘制调用排序)
    - [1.4. touch(ViewId id)函数和touch(0)](#14-touchviewid-id函数和touch0)
    - [1.5. submit和frame的关系](#15-submit和frame的关系)
    - [1.6. setTransform函数](#16-settransform函数)
    - [1.7. 编译bgfx官方的shaderc工具](#17-编译bgfx官方的shaderc工具)
    - [1.8. bgfx调式策略](#18-bgfx调式策略)
    - [1.9. 使用bgfx_create_shader函数程序崩溃](#19-使用bgfx_create_shader函数程序崩溃)
    - [1.10. 纹理格式](#110-纹理格式)

<!-- /TOC -->

# 1. FAQ for bgfx

## 1.1. 阅读bgfx源代码策略

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

## 1.2. 多个View的绘制顺序

默认情况下View是从小到大绘制的，但可以使用setViewOrder来重新映射，从而改变绘制顺序。

一个View代表的是一组状态和一组绘制调用，是一个**抽象**的概念。

View的排序是通过编码进行的，View的编码位于高位，所以在排序时可以认为ViewID是第一关键字

(内部实现是通过把一次绘制调用打包为一个64进制数，ViewID也被打包进去，然后对其进行排序，具体参考SortKey.md)


## 1.3. bgfx的绘制调用排序

bgfx的绘制调用排序是使用SortKey完成的(SortKey的定义和代码在bgfx_ph.h中)。

## 1.4. touch(ViewId id)函数和touch(0)

touch函数实际上就是一个空的submit调用。
touch(0)实际上就是submit(0,BGFX_INVALID_HANDLE)

## 1.5. submit和frame的关系

frame由0个或1个或多个submit提交的信息构成。可以这样认为frame是一个submit的集合。

## 1.6. setTransform函数

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

## 1.7. 编译bgfx官方的shaderc工具

安装好编译工具链后进入bgfx的源代码目录执行make shaderc。

如果提示信息缺少yacc和lex，使用pacman -S bison flex来安装yacc和lex。

如果还无法编译成功的话运行bgfx/3rdparty/glsl-optimizer/generateParsers.sh脚本

然后在bgfx目录下运行make shaderc。

## 1.8. bgfx调式策略

bgfx向debugger输出了很多调试信息，遇到莫名的问题，查看debugger的效率会高很多。

bgfx输出错误信息使用的是bx的debugOutput函数(位于bx\src\debug.cpp中)，在里面使用条件编译根据平台选择合适的输出途径，

在windows下使用的是Windows API函数OutputDebugString。

bgfx提供了回调来设置输出调试信息，所以我们也可以通过设置这个回调来获取bgfx的报错信息。

## 1.9. 使用bgfx_create_shader函数程序崩溃

bgfx_create_shader接受的shader类型依赖于指定的渲染器，如果指定了OpenGL为渲染器就不能使用DX的，bgfx_create_shader接受的参数实际为特定渲染器的特定编译后的二进制格式。

指定渲染器使用bgfx_init函数进行，设置参数变量的type为指定渲染器即可。

## 1.10. 纹理格式

bgfx使用的纹理格式实际定义可以在renderer_gl.cpp的static TextureFormatInfo s_textureFormat找到

            static TextureFormatInfo s_textureFormat[] =
            {
                { GL_COMPRESSED_RGBA_S3TC_DXT1_EXT,            GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT,        GL_COMPRESSED_RGBA_S3TC_DXT1_EXT,            GL_ZERO,                         false }, // BC1
                { GL_COMPRESSED_RGBA_S3TC_DXT3_EXT,            GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT,        GL_COMPRESSED_RGBA_S3TC_DXT3_EXT,            GL_ZERO,                         false }, // BC2
                { GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,            GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT,        GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,            GL_ZERO,                         false }, // BC3
                { GL_COMPRESSED_LUMINANCE_LATC1_EXT,           GL_ZERO,                                       GL_COMPRESSED_LUMINANCE_LATC1_EXT,           GL_ZERO,                         false }, // BC4
                { GL_COMPRESSED_LUMINANCE_ALPHA_LATC2_EXT,     GL_ZERO,                                       GL_COMPRESSED_LUMINANCE_ALPHA_LATC2_EXT,     GL_ZERO,                         false }, // BC5
                { GL_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB,     GL_ZERO,                                       GL_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB,     GL_ZERO,                         false }, // BC6H
                { GL_COMPRESSED_RGBA_BPTC_UNORM_ARB,           GL_ZERO,                                       GL_COMPRESSED_RGBA_BPTC_UNORM_ARB,           GL_ZERO,                         false }, // BC7
                { GL_ETC1_RGB8_OES,                            GL_ZERO,                                       GL_ETC1_RGB8_OES,                            GL_ZERO,                         false }, // ETC1
                { GL_COMPRESSED_RGB8_ETC2,                     GL_ZERO,                                       GL_COMPRESSED_RGB8_ETC2,                     GL_ZERO,                         false }, // ETC2
                { GL_COMPRESSED_RGBA8_ETC2_EAC,                GL_COMPRESSED_SRGB8_ETC2,                      GL_COMPRESSED_RGBA8_ETC2_EAC,                GL_ZERO,                         false }, // ETC2A
                { GL_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2, GL_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2,  GL_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2, GL_ZERO,                         false }, // ETC2A1
                { GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG,          GL_COMPRESSED_SRGB_PVRTC_2BPPV1_EXT,           GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG,          GL_ZERO,                         false }, // PTC12
                { GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG,          GL_COMPRESSED_SRGB_PVRTC_4BPPV1_EXT,           GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG,          GL_ZERO,                         false }, // PTC14
                { GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG,         GL_COMPRESSED_SRGB_ALPHA_PVRTC_2BPPV1_EXT,     GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG,         GL_ZERO,                         false }, // PTC12A
                { GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG,         GL_COMPRESSED_SRGB_ALPHA_PVRTC_4BPPV1_EXT,     GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG,         GL_ZERO,                         false }, // PTC14A
                { GL_COMPRESSED_RGBA_PVRTC_2BPPV2_IMG,         GL_ZERO,                                       GL_COMPRESSED_RGBA_PVRTC_2BPPV2_IMG,         GL_ZERO,                         false }, // PTC22
                { GL_COMPRESSED_RGBA_PVRTC_4BPPV2_IMG,         GL_ZERO,                                       GL_COMPRESSED_RGBA_PVRTC_4BPPV2_IMG,         GL_ZERO,                         false }, // PTC24
                { GL_ATC_RGB_AMD,                              GL_ZERO,                                       GL_ATC_RGB_AMD,                              GL_ZERO,                         false }, // ATC
                { GL_ATC_RGBA_EXPLICIT_ALPHA_AMD,              GL_ZERO,                                       GL_ATC_RGBA_EXPLICIT_ALPHA_AMD,              GL_ZERO,                         false }, // ATCE
                { GL_ATC_RGBA_INTERPOLATED_ALPHA_AMD,          GL_ZERO,                                       GL_ATC_RGBA_INTERPOLATED_ALPHA_AMD,          GL_ZERO,                         false }, // ATCI
                { GL_COMPRESSED_RGBA_ASTC_4x4_KHR,             GL_COMPRESSED_SRGB8_ASTC_4x4_KHR,              GL_COMPRESSED_RGBA_ASTC_4x4_KHR,             GL_ZERO,                         false }, // ASTC4x4
                { GL_COMPRESSED_RGBA_ASTC_5x5_KHR,             GL_COMPRESSED_SRGB8_ASTC_5x5_KHR,              GL_COMPRESSED_RGBA_ASTC_5x5_KHR,             GL_ZERO,                         false }, // ASTC5x5
                { GL_COMPRESSED_RGBA_ASTC_6x6_KHR,             GL_COMPRESSED_SRGB8_ASTC_6x6_KHR,              GL_COMPRESSED_RGBA_ASTC_6x6_KHR,             GL_ZERO,                         false }, // ASTC6x6
                { GL_COMPRESSED_RGBA_ASTC_8x5_KHR,             GL_COMPRESSED_SRGB8_ASTC_8x5_KHR,              GL_COMPRESSED_RGBA_ASTC_8x5_KHR,             GL_ZERO,                         false }, // ASTC8x5
                { GL_COMPRESSED_RGBA_ASTC_8x6_KHR,             GL_COMPRESSED_SRGB8_ASTC_8x6_KHR,              GL_COMPRESSED_RGBA_ASTC_8x6_KHR,             GL_ZERO,                         false }, // ASTC8x6
                { GL_COMPRESSED_RGBA_ASTC_10x5_KHR,            GL_COMPRESSED_SRGB8_ASTC_10x5_KHR,             GL_COMPRESSED_RGBA_ASTC_10x5_KHR,            GL_ZERO,                         false }, // ASTC10x5
                { GL_ZERO,                                     GL_ZERO,                                       GL_ZERO,                                     GL_ZERO,                         false }, // Unknown
                { GL_ZERO,                                     GL_ZERO,                                       GL_ZERO,                                     GL_ZERO,                         false }, // R1
                { GL_ALPHA,                                    GL_ZERO,                                       GL_ALPHA,                                    GL_UNSIGNED_BYTE,                false }, // A8
                { GL_R8,                                       GL_ZERO,                                       GL_RED,                                      GL_UNSIGNED_BYTE,                false }, // R8
                { GL_R8I,                                      GL_ZERO,                                       GL_RED,                                      GL_BYTE,                         false }, // R8I
                { GL_R8UI,                                     GL_ZERO,                                       GL_RED,                                      GL_UNSIGNED_BYTE,                false }, // R8U
                { GL_R8_SNORM,                                 GL_ZERO,                                       GL_RED,                                      GL_BYTE,                         false }, // R8S
                { GL_R16,                                      GL_ZERO,                                       GL_RED,                                      GL_UNSIGNED_SHORT,               false }, // R16
                { GL_R16I,                                     GL_ZERO,                                       GL_RED,                                      GL_SHORT,                        false }, // R16I
                { GL_R16UI,                                    GL_ZERO,                                       GL_RED,                                      GL_UNSIGNED_SHORT,               false }, // R16U
                { GL_R16F,                                     GL_ZERO,                                       GL_RED,                                      GL_HALF_FLOAT,                   false }, // R16F
                { GL_R16_SNORM,                                GL_ZERO,                                       GL_RED,                                      GL_SHORT,                        false }, // R16S
                { GL_R32I,                                     GL_ZERO,                                       GL_RED,                                      GL_INT,                          false }, // R32I
                { GL_R32UI,                                    GL_ZERO,                                       GL_RED,                                      GL_UNSIGNED_INT,                 false }, // R32U
                { GL_R32F,                                     GL_ZERO,                                       GL_RED,                                      GL_FLOAT,                        false }, // R32F
                { GL_RG8,                                      GL_ZERO,                                       GL_RG,                                       GL_UNSIGNED_BYTE,                false }, // RG8
                { GL_RG8I,                                     GL_ZERO,                                       GL_RG,                                       GL_BYTE,                         false }, // RG8I
                { GL_RG8UI,                                    GL_ZERO,                                       GL_RG,                                       GL_UNSIGNED_BYTE,                false }, // RG8U
                { GL_RG8_SNORM,                                GL_ZERO,                                       GL_RG,                                       GL_BYTE,                         false }, // RG8S
                { GL_RG16,                                     GL_ZERO,                                       GL_RG,                                       GL_UNSIGNED_SHORT,               false }, // RG16
                { GL_RG16I,                                    GL_ZERO,                                       GL_RG,                                       GL_SHORT,                        false }, // RG16I
                { GL_RG16UI,                                   GL_ZERO,                                       GL_RG,                                       GL_UNSIGNED_SHORT,               false }, // RG16U
                { GL_RG16F,                                    GL_ZERO,                                       GL_RG,                                       GL_FLOAT,                        false }, // RG16F
                { GL_RG16_SNORM,                               GL_ZERO,                                       GL_RG,                                       GL_SHORT,                        false }, // RG16S
                { GL_RG32I,                                    GL_ZERO,                                       GL_RG,                                       GL_INT,                          false }, // RG32I
                { GL_RG32UI,                                   GL_ZERO,                                       GL_RG,                                       GL_UNSIGNED_INT,                 false }, // RG32U
                { GL_RG32F,                                    GL_ZERO,                                       GL_RG,                                       GL_FLOAT,                        false }, // RG32F
                { GL_RGB8,                                     GL_SRGB8,                                      GL_RGB,                                      GL_UNSIGNED_BYTE,                false }, // RGB8
                { GL_RGB8I,                                    GL_ZERO,                                       GL_RGB,                                      GL_BYTE,                         false }, // RGB8I
                { GL_RGB8UI,                                   GL_ZERO,                                       GL_RGB,                                      GL_UNSIGNED_BYTE,                false }, // RGB8U
                { GL_RGB8_SNORM,                               GL_ZERO,                                       GL_RGB,                                      GL_BYTE,                         false }, // RGB8S
                { GL_RGB9_E5,                                  GL_ZERO,                                       GL_RGB,                                      GL_UNSIGNED_INT_5_9_9_9_REV,     false }, // RGB9E5F
                { GL_RGBA8,                                    GL_SRGB8_ALPHA8,                               GL_BGRA,                                     GL_UNSIGNED_BYTE,                false }, // BGRA8
                { GL_RGBA8,                                    GL_SRGB8_ALPHA8,                               GL_RGBA,                                     GL_UNSIGNED_BYTE,                false }, // RGBA8
                { GL_RGBA8I,                                   GL_ZERO,                                       GL_RGBA,                                     GL_BYTE,                         false }, // RGBA8I
                { GL_RGBA8UI,                                  GL_ZERO,                                       GL_RGBA,                                     GL_UNSIGNED_BYTE,                false }, // RGBA8U
                { GL_RGBA8_SNORM,                              GL_ZERO,                                       GL_RGBA,                                     GL_BYTE,                         false }, // RGBA8S
                { GL_RGBA16,                                   GL_ZERO,                                       GL_RGBA,                                     GL_UNSIGNED_SHORT,               false }, // RGBA16
                { GL_RGBA16I,                                  GL_ZERO,                                       GL_RGBA,                                     GL_SHORT,                        false }, // RGBA16I
                { GL_RGBA16UI,                                 GL_ZERO,                                       GL_RGBA,                                     GL_UNSIGNED_SHORT,               false }, // RGBA16U
                { GL_RGBA16F,                                  GL_ZERO,                                       GL_RGBA,                                     GL_HALF_FLOAT,                   false }, // RGBA16F
                { GL_RGBA16_SNORM,                             GL_ZERO,                                       GL_RGBA,                                     GL_SHORT,                        false }, // RGBA16S
                { GL_RGBA32I,                                  GL_ZERO,                                       GL_RGBA,                                     GL_INT,                          false }, // RGBA32I
                { GL_RGBA32UI,                                 GL_ZERO,                                       GL_RGBA,                                     GL_UNSIGNED_INT,                 false }, // RGBA32U
                { GL_RGBA32F,                                  GL_ZERO,                                       GL_RGBA,                                     GL_FLOAT,                        false }, // RGBA32F
                { GL_RGB565,                                   GL_ZERO,                                       GL_RGB,                                      GL_UNSIGNED_SHORT_5_6_5,         false }, // R5G6B5
                { GL_RGBA4,                                    GL_ZERO,                                       GL_RGBA,                                     GL_UNSIGNED_SHORT_4_4_4_4_REV,   false }, // RGBA4
                { GL_RGB5_A1,                                  GL_ZERO,                                       GL_RGBA,                                     GL_UNSIGNED_SHORT_1_5_5_5_REV,   false }, // RGB5A1
                { GL_RGB10_A2,                                 GL_ZERO,                                       GL_RGBA,                                     GL_UNSIGNED_INT_2_10_10_10_REV,  false }, // RGB10A2
                { GL_R11F_G11F_B10F,                           GL_ZERO,                                       GL_RGB,                                      GL_UNSIGNED_INT_10F_11F_11F_REV, false }, // RG11B10F
                { GL_ZERO,                                     GL_ZERO,                                       GL_ZERO,                                     GL_ZERO,                         false }, // UnknownDepth
                { GL_DEPTH_COMPONENT16,                        GL_ZERO,                                       GL_DEPTH_COMPONENT,                          GL_UNSIGNED_SHORT,               false }, // D16
                { GL_DEPTH_COMPONENT24,                        GL_ZERO,                                       GL_DEPTH_COMPONENT,                          GL_UNSIGNED_INT,                 false }, // D24
                { GL_DEPTH24_STENCIL8,                         GL_ZERO,                                       GL_DEPTH_STENCIL,                            GL_UNSIGNED_INT_24_8,            false }, // D24S8
                { GL_DEPTH_COMPONENT32,                        GL_ZERO,                                       GL_DEPTH_COMPONENT,                          GL_UNSIGNED_INT,                 false }, // D32
                { GL_DEPTH_COMPONENT32F,                       GL_ZERO,                                       GL_DEPTH_COMPONENT,                          GL_FLOAT,                        false }, // D16F
                { GL_DEPTH_COMPONENT32F,                       GL_ZERO,                                       GL_DEPTH_COMPONENT,                          GL_FLOAT,                        false }, // D24F
                { GL_DEPTH_COMPONENT32F,                       GL_ZERO,                                       GL_DEPTH_COMPONENT,                          GL_FLOAT,                        false }, // D32F
                { GL_STENCIL_INDEX8,                           GL_ZERO,                                       GL_STENCIL_INDEX,                            GL_UNSIGNED_BYTE,                false }, // D0S8
            };
