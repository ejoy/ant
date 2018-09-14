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

                ViewRect,
                ViewTexel
                View
                InvView
                Proj
                InvProj
                ViewProj
                InvViewProj
                Model
                ModelView
                ModelViewProj
                AlphaRef

通过阅读bgfx的OpenGL后端实现，可以发现bgfx对于预定义uniform
