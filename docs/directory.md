* 3rd 第三方库
	* 3rd/bee.lua
	* 3rd/bgfx 图形渲染 API
	* 3rd/bimg bgfx 的图形文件库
	* 3rd/bx bgfx 的辅助库
	* 3rd/Effekseer 特效库
	* 3rd/fmod 声音库
	* 3rd/glm 数学库
	* 3rd/imgui 编辑器用 UI 库
	* 3rd/ltask Lua 多任务库
	* 3rd/luaecs ECS 库
	* 3rd/math3d 数学库的 Lua 封装
	* 3rd/MoltenVK Metal 的 Vulkan 模拟层
	* 3rd/ozz-animation 动画库
	* 3rd/scripts 3rd 的编译脚本
	* 3rd/SDL SDL 用于窗口事件处理
	* 3rd/stylecache CSS style 管理
	* 3rd/vulkan Windows 下的 Vulkan 库
	* 3rd/yoga CSS 排版
* bin luamake 构建结果
* build luamake 构建中间文件
* clibs Lua 用到的若干 C 库
	* clibs/bake 离线烘培
	* clibs/bee bee.lua 的编译脚本
	* clibs/bgfx bgfx 的 Lua binding
	* clibs/crypt SHA1 等加密模块
	* clibs/datalist 类似 yaml 的结构化数据文件
	* clibs/ecs luaecs 的 C++ 封装
	* clibs/fastio 用于 Lua 的 IO 模块
	* clibs/filedialog 对话框
	* clibs/fileinterface 文件 API 接口
	* clibs/firmware 手机 App 的启动用模块
	* clibs/font 字体管理
	* clibs/foundation C 模块使用的基础设施
	* clibs/hierarchy 场景层次结构
	* clibs/image bimg 的 Lua 封装
	* clibs/imgui imgui 的 Lua 封装
	* clibs/ltask ltask 的编译脚本
	* clibs/lua lua 的编译脚本
	* clibs/luabind Lua binding 用的库
	* clibs/math3d math3d 的编译脚本
	* clibs/protocol fileserver 通讯协议
	* clibs/quadsphere 立方体球（废弃？）
	* clibs/terrain 地形模块
	* clibs/vfs VFS (虚拟文件系统) 的 C 部分
	* clibs/window 各平台的窗口模块
* docs 文档
* engine 引擎中不受包管理的 Lua 代码
	* engine/editor 编辑器模式相关
	* engine/firmware 游戏客户端的自举部分及基础库
	* engine/runtime 运行时模式相关
	* engine/task  游戏客户端的 ltask 启动
		* engine/task/service 游戏客户端的 ltask 服务
	* engine/vfs VFS 相关
* misc 其它（文本编辑器插件）
* pkg 引擎的包
	* pkg/ant.animation 动画
	* pkg/ant.argument 
	* pkg/ant.asset 资源管理
	* pkg/ant.atmosphere
	* pkg/ant.audio 声音
	* pkg/ant.bake
	* pkg/ant.camera
	* pkg/ant.compile_resource 资源编译
	* pkg/ant.daynight 晨昏变换
	* pkg/ant.debug
	* pkg/ant.debugger
	* pkg/ant.decal
	* pkg/ant.world
	* pkg/ant.editor
	* pkg/ant.efk 特效
	* pkg/ant.font 字体
	* pkg/ant.general
	* pkg/ant.geometry
	* pkg/ant.group
	* pkg/ant.hwi
	* pkg/ant.imgui 编辑器用 UI （IMGUI）
	* pkg/ant.json
	* pkg/ant.landform
	* pkg/ant.luaecs
	* pkg/ant.material 材质
	* pkg/ant.math
	* pkg/ant.math.adapter 数学库用桥接器（把矩阵向量指针转换为数学 ID）
	* pkg/ant.modifier
	* pkg/ant.motion_sampler
	* pkg/ant.objcontroller
	* pkg/ant.outline
	* pkg/ant.polyline
	* pkg/ant.render 渲染层
		* pkg/ant.render/billboard
		* pkg/ant.render/components
		* pkg/ant.render/compute
		* pkg/ant.render/cull
		* pkg/ant.render/depth
		* pkg/ant.render/draw_indirect
		* pkg/ant.render/hitch
		* pkg/ant.render/ibl
		* pkg/ant.render/light
		* pkg/ant.render/lightmap
		* pkg/ant.render/main.lua
		* pkg/ant.render/make.lua
		* pkg/ant.render/package.ecs
		* pkg/ant.render/postprocess
		* pkg/ant.render/preprocess
		* pkg/ant.render/render
		* pkg/ant.render/render_layer
		* pkg/ant.render/render_system
		* pkg/ant.render/shadow
		* pkg/ant.render/skinning
		* pkg/ant.render/uv_motion
		* pkg/ant.render/velocity
		* pkg/ant.render/view_group
		* pkg/ant.render/viewport
	* pkg/ant.render.core 渲染层中被其它包依赖的部分
	* pkg/ant.resource_manager 资源管理模块
		* pkg/ant.resource_manager/service 资源管理 (ltask) 服务
		* pkg/ant.resource_manager/src 资源管理用到的 C 模块（用于绕过 Lua 层直接用过 C API 获取资源）
		* pkg/ant.resource_manager/thread 资源管理服务用到的 Lua 模块
	* pkg/ant.resources 引擎中定义的文本资源
		* pkg/ant.resources/materials 材质
		* pkg/ant.resources/settings 材质的配置
		* pkg/ant.resources/shaders 着色器
		* pkg/ant.resources/state_machines （？？？）
		* pkg/ant.resources/textures 默认纹理
	* pkg/ant.resources.binary 引擎中定义的二进制资源
	* pkg/ant.rmlui 游戏用 UI （RMLUI）
	* pkg/ant.scene
	* pkg/ant.serialize
	* pkg/ant.settings
	* pkg/ant.sh
	* pkg/ant.shadow_bounding
	* pkg/ant.sky
	* pkg/ant.splitviews
	* pkg/ant.starsky
	* pkg/ant.terrain
	* pkg/ant.timer
	* pkg/ant.widget
	* pkg/ant.window
* runtime 引擎运行时的不同平台支持
* test 测试项目
* tools 工具
	* tools/baker
	* tools/dump-prefab
	* tools/editor
	* tools/fbx2glb
	* tools/fileserver 引擎运行时需要的开发机服务
		* tools/fileserver/pkg/s  fileserver 用到的模块
			* tools/fileserver/pkg/s/service fileserver 中的各 ltask 服务
	* tools/install
	* tools/material_compile
	* tools/pdxmesh
	* tools/prefab_viewer
	* tools/rmlviewer
	* tools/texture