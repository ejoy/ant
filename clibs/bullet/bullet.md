## bulletworld 
   提供物理碰撞检测功能：射线，物体之间
   显示 box,capsule,sphere，cylinder ... 等物理几何形体的调试功能
   collider & component 的创建，使用，回收等功能
   物体移动旋转等控制设置功能

## clibs/bullet 物理模块 ===
    bulletworld.lua                    物理SDK Lua 用户层接口(LUA LAYER API)
    bullet.cpp                         lua binding interface 

## clibs/bullet/collision 物理功能底层实现
    CollisionSdkC_Api.h,.cpp           c interface for c user or script binding 
    CollisionSdkInterface              bullet sdk 抽象接口,用来支持不同的sdk版本
    Bullet2CollisionSdk.h,.cpp         bullet 各种物理对象和功能的实现集合
    BulletDebugDraw.h                  debugDrawer 物理对象形体辅助绘制器，用于观察调式

    当前bulletworld 模块优先实现 collisionWorld ，能够提供非刚体等物理模拟外的所有碰检功能，
    如果后续有物理模拟需求，扩充 Bullet2CollisionSdk 即可，其结构和对象方法基本一致。

## 相关概念
    bullet 等物理系统，使用 world/object/shape 等物理对象,来对应渲染世界中的worl/entity(mesh)等逻辑对象，实现高解耦的使用方式。用户在逻辑世界中加减渲染物体时，使用物理 API 同步增删物理对象，构建镜像的物理世界。bulletworld 尽量精简API,提供 Physics:raycast ,collide_objects 等简单易用接口, 方便使用。简单函数完成射线拾取，碰撞检测，或物理模拟等功能。同时提供关联查询方法，可向逻辑世界反馈运动变化或拾取碰撞关联的物体。

    bulletworld 可以工作在两种模式下：
                1. 作为系统SDK 的方式提供基础服务
                2. 作为system，独立运行，提供服务，执行物理模拟。

## collider component 
   clibs/bullet/component_collider.lua
   针对 ecs 系统提供的对应 collider 组件，创建，持有使用，回收物理对象的方法。

   local collider = ecs.component "collider" {
   info = {
        type = "userdata",           -- for ecs 
        default = {                  -- for user 
   ###--1. 系列化/反系列化数据
            type = "box",            -- for collider component recognize type
                -- type string("box","sphere","cylinder","capsule","plane","compound","terrain")
            center = {0,0,0},
            sx = 1, sy = 1, sz = 1, 

   ###--2. 运行时物理对象数据 
            obj,shape
        }
        save()
        load()
   }
   ###--3. 回收函数，当entity 释放时,collider component 需要释放物理对象
   function collider:delete()
      -- recycle obj,shape 
   end 
   
   其中 1，2，3 项，提供了collider component 的持久系列化需要的数据，运行时查询功能，
   回收释放物理对象功能。

   box_collider,capsule_* 等具有详细名称的 component 仍旧保留可以，但建议都以 collider 代替。
   使用 collider 作为唯一的 component 名称，使用 type = "box" 作为 collider类型查询，更加
   方便 ecs 开发者使用。

## 使用方法
   bulletworld.lua 作为 bullet 唯一用户 API 
   
   .使用步骤
   1. local bulletworld = require "bulletworld"      加载物理模块
   2. local Physics  =  bulletworld.new()            程序启动时，创建物理世界
      
   3. loadScene,updateScene
         Physics:reset_world()                       清掉上个场景的所有 objects 数据
         Physics:create_collider()
            ......
            Physics:raycast()                        运行时循环使用
            Physics:set_ojectt_angles(obj,...)
            Physics:set_object_position(obj,...)     设置物体，位置方向缩放等
            Physics:set_object_scale(obj,...)       
            ....
         Physics:remove_collider()

   4. Physics:delete()                               程序关闭时，删除物理世界

   5. 也可以每次场景切换时 new/delete 物理世界，但不建议

## 主要 API 组成完整有效的应用
   
   1. 创建 component & collider component API

      Physics:add_component_collider  (几何碰撞器)          -- "box","sphere","capsule","cylinder"
      Physics:add_component_tercollider (地形碰撞器)        -- "terrain"

      local shape_info ={ type = "box", center = {}, ... } 
	   Physics:add_component_collider(world,bunny_eid,"box",ms,shape_info) -- 系列化，编辑化的模式
      Physics:add_component_collider(world,bunny_eid,"box",ms)           -- 自动创建模式

      为 entity 创建 collider component 和 物理 object，shape 
      当不填写 info 时，可以使用 type="box" 等指定类型进行自动创建，方便快速使用及测试;
      当填写 info 时，则提供了对shape信息进行手工调整的能力，info 同时是组件数据系列化的结构。

   2. 调式 API 
      Physics:set_debug_drawer("on",bgfx)  -- 开启调试绘画功能

      --------
      Physics:add_component_collider(..,"box",...)
      Physics:drawline(pt1,pt2,color)      -- pt1 = {0,1,0}, color = 0xffffffff
      Physics:begin_draw_world()           -- 开始绘制
      Physics:get_debug_info()             -- 获取绘制数据句柄
        AnyRenderer:render()               
      Physics:end_draw_world()             -- 结束绘制
      --------
      
      Physics:set_debug_drawer("off")      -- 关闭调试绘画功能
    
   3. 查询碰撞检测 API 
      Physics:raycast                      -- 射线检测，拾取，行走碰撞的基础函数
      Physics:collide_objects              -- 判断两个objects 是否碰撞的函数



### *其余各种细节API,如 object，shape 创建使用功能则为基础的函数，基本上都可以被上述 3类API 代替使用；
### *当需要做简单测试，或特殊用途时，可以直接组合使用。

## 相关新增用例 system 
    charcontroller_sys.lua  简单角色行走控制器，按需求，当前实现可以在模拟场景中流畅行走，爬高，
                            碰撞停止等功能。
                            目前和 cameracontroller.lua 共用一个 main_camera 相机，
                            测试时，需要屏蔽 cameracontroller.lua 
                            后期，系统需要考虑这些共有entity 的使用行为，调整使用方式。实现有效切换或系统的共存。

                            需要屏蔽cameracontroller_system.lua 避免其作为打开场景的默认system, 只在需要使用的场景module 中添加。 

    physics_system.lua      简单物理系统框架，可以用之扩充新的使用功能,包括物理模拟等

## 相关用例修改
   在使用和测试的过程中，如下几个文件增加了对应的component
   terrain collider，geometry shape collider ，包括对应的多种使用方法，删除回收方法
   terrain_system.lua                       -- terrain collider component 
   pvpscene.lua                             -- collider component
   add_entity_phy_system.lua                -- collider component 多种创建方法


