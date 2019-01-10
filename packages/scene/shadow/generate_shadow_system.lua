local ecs = ...
local world = ecs.world



local render_cu = import_package "render".components
local render_util = import_package "render".util
local math_util = (import_package "math").util
local math3d = require "math3d"
local bgfx = require "bgfx"
local asset = import_package "asset"
local ms = (import_package "math").stack

-- system rules 
-- component for global state
-- util function for all system share
-- delay resolve
-- Systems can not call other systems 

-- mesh_shadow as utility 
-- 常规配置参数,调试对比方便配置
local SHADOWMAP_SIZE = 1024     
local NEAR = 0.3125
local FAR  = 450 
local SPLIT_WEIGHT = 0.7
local NUM_SPLITS = 4

local TEXTURE_UINT_START     = 4 

local VIEWID_SHADOW          = 10

local VIEWID_SHADOW_START    = 11
local VIEWID_SHADOW_END      = 14 

local VIEWID_DRAWSCENE = 200

local VIEWID_DRAWDEPTH_START = 205
local VIEWID_DRAWDEPTH_END   = 208

-- tested helper 
local ctx = {}
ctx.width  = 1280  -- default 
ctx.height = 720
ctx.projHeight  =  math.tan(math.rad(60)*0.5) 
ctx.projWidth   =  ctx.projHeight*(ctx.width/ctx.height)

ctx.timeLight = 0
ctx.light = {}
ctx.directionLight = {}
ctx.shadowMapMtx = {}
ctx.s_rtShadowMap = {}
ctx.shadowMapSize = SHADOWMAP_SIZE
ctx.shadowMapTexelSize = 1/SHADOWMAP_SIZE 
ctx.s_flipV = false       -- d3d or ogl

-- make shadowmap as entity
-- 当存在 shadowmap entity 时，启动动态阴影，否则阴影系统不执行
-- 以一个 entity 作为控制阴影系统开关标志,应该有一定的便利性
-- 
-- 或者 shadowmap system 的配置和控制属性属于系统本身，可以依赖系统存在
-- 而属于 world entity 与外部交互的运行时数据仍旧保持独立性，
-- 不影响 system 与数据无关性原则?

-- shadowmap entity, other system get shadow texture from this entity

-- 定义 shadowmap entity 相关组件数据( 生成配置, 结果数据, ... )
-- shadowmap settings
local shadow_config = ecs.component_struct "shadow_config" { 

}
-- shadowmap runtime status, result id handle,result textures,matrixs,framebuffers
local shadow_rt = ecs.component_struct "shadow_rt" {

}

-- setting & result  
-- 可修改设置集
function shadow_config:init()
    -- should be read from config, and material asset
    self.shadowMapSize = SHADOWMAP_SIZE
    self.near = NEAR 
    self.far  = FAR         
    self.numSplits =  NUM_SPLITS
    self.splitDistribution = SPLIT_WEIGHT 
    self.stabilize = true  

    -- for params2
    self.depthValuePow   = 10
    self.showSmCoverage = true     
    self.shadowMapTexelSize = 1/self.shadowMapSize 
    self.ss_offsetx = 1
    self.ss_offsety = 1

    -- for params1
    self.shadowMapBias   = 0.0000015*FAR    
    self.shadowMapOffset = 0.5  --0.2    
    self.shadowMapParam0 = 0         
    self.shadowMapParam1 = 0                                             
                                     -- hard = none,none 
                                     -- pcf = u_shadowMapPcfMode,u_shadowMapNoiseAmount
                                     -- vsm = u_shadowMapMinVariance,u_shadowMapDepthMultiplier
                                     -- esm = u_shadowMapHardness,u_shadowMapDepthMultiplier

    -- self.u_smSamplingParams       -- pcf 采样参数

    self.lightType  = "DirectionLight"
    self.depthImpl  = "InvZ"
    self.shadowImpl = "PCF"

    self.debug_drawShadow = false 
    self.debug_drawLightView = false 
    self.debug_virtualCamera = false
    self.debug_virtualLight = false       
    self.debug_drawScene = false        
                                                   -- depth generate method
    self.progShadow   = "packDepth_InvZ_RGBA"      -- inverse z depth method    
    --self.progShadow = "packDepth_Linear_RGBA"   
    --self.progShadow = "drawDepth_RGBA"   
end

-- 使用结果集
function shadow_rt:init()
    -- runtime & result 
    -- ctx overlay data
    self.ready = true                 -- shadowmaps have generated , render system query this flag
    -- comp_rt.shadowMapSize          -- shadow size
    -- comp_rt.shadowMapTexelSize     -- shadow texel size
    -- comp_rt.s_rtShadowMap = {}     -- framebuffers[] & shadowTextures[]
    -- comp_rt.shadowMapMtx = {}      -- light shadow matrices 

    -- comp_rt.lightView[4]           -- rumtime 
    -- comp_rt.lightProj[4]           --  
end 

-- or combine mode 
-- 合并成一个 compoent 内的两个表? may be clear more,but not use now 
local shadow = ecs.component_struct "shadow_maker" {}
function shadow:init()
    self.config = {}
    self.shadow = {}
end 

-- shadowmap 相关结构数据整理，如何归纳使用，哪些属于 component ，哪些属于系统控制本身
--  按 ecs 原则，这些变量需要有个 component 或者 entity ，singleton 来定义或保存
--  这里先整理出需要的数据结构

-- read light parameters form direct light entity 
-- 运行中的动态数据，根据 shadow_config 来计算产生
-- 不属于任何其他system 自身需要的中间状态
-- overwatch system 也是有临时控制结构，表明系统自身动作,折中 
local lightView = {}
local lightProj = {}
local frustumCorners = {}
local mtxCropBias = {}       -- for point lights, do not need this time 

-- uniforms --
-- define all vars  and relative uniforms
-- 应该从 shadowmap material 材质创建 uniforms,实现可配置化
local uniforms = {}
local function uniform_def(name, t )
    uniforms[name] = bgfx.create_uniform(name,t or "v4")
end 
local function var_def(tbl,name,...)
    local vec = math3d.ref "vector"  
    ms(vec,{...},"=")             
    tbl[name] = vec                  
end 
local function var_set(name,...)
    ms(uniforms[name],{...},"=")
end 
local function var_undef(name)
    math3d.unref( uniforms[name] )
end 


local function init_uniforms()

    uniforms.ambientPass  = 1
    uniforms.lightingPass = 1

    uniforms.shadowMapBias   = 0.0000015*FAR  
    uniforms.shadowMapOffset = 0.20        
    uniforms.shadowMapParam0 = 0.5
    uniforms.shadowMapParam1 = 1

    uniforms.depthValuePow = 10
    uniforms.showSmCoverage = 1
    uniforms.shadowMapTexelSize = 1/SHADOWMAP_SIZE
    uniforms.shadowMapSize = SHADOWMAP_SIZE

    uniforms.ss_offsetx = 1
    uniforms.ss_offsety = 1 
     
    uniforms.s_shadowMap0 = false 
    uniforms.s_shadowMap1 = false 

    uniforms.csmFarDistances = { 30,90,180,1000 }

    uniforms.activeLight = false                       -- current active light 

    -- def(uniforms,"params0",1,1,0,0)                 -- ambientPass,lightingPass not used now 
    -- def(uniforms,"params1",0.003,0,0.5,1)           -- bias,offset, shadowMapParam0，shadowMapParam1
    -- def(uniforms,"params2",1,1,1/SHADOWMAP_SIZE,0)  -- depthPow,SmCoverage,smTexelSize
    -- def(uniforms,"csmFarDistances",30,90,180,1000)  -- csm split distances
end 

local function screenSpaceQuad( textureWidth,textureHeight, originBottomLeft)
    local width = 1
	local height = 1

	ctx.color_tb:alloc(3, ctx.PosColorTexCoord0Vertex)

	local zz = 0
	local minx = -width
	local maxx = width
	local miny = 0
	local maxy = height * 2

	local texelHalfW = ctx.s_texelHalf / textureWidth
	local texelHalfH = ctx.s_texelHalf / textureHeight
	local minu = -1 + texelHalfW
	local maxu = 1 + texelHalfW

	local minv = texelHalfH
	local maxv = 2 + texelHalfH

	if originBottomLeft then
		minv, maxv = maxv, minv
		minv = minv - 1
		maxv = maxv - 1
	end

	ctx.color_tb:packV(0, minx, miny, zz, 0xffffffff, minu, minv)
	ctx.color_tb:packV(1, maxx, miny, zz, 0xffffffff, maxu, minv)
	ctx.color_tb:packV(2, maxx, maxy, zz, 0xffffffff, maxu, maxv)

	ctx.color_tb:set()
end 

-----------------------------------------------
-- shadow maker util
local shadow_maker = {}
shadow_maker.__index = shadow_maker 

-- shadow_maker init 
function  shadow_maker:init( shadow_maker_entity )

	local sm_name = "shadow.material"
	local depictiondir = asset.depictiondir()
    local shadow_material = asset.load( depictiondir / sm_name )
    shadow_material.name = sm_name 

    local depth_name = "drawdepth.material"
    local drawdepth_material = asset.load( depictiondir / depth_name )
    drawdepth_material.name = depth_name 

    local drawscene_name = "PVPScene/scene-mat-shadow.material"
    local drawscene_material = asset.load( depictiondir / drawscene_name )
    drawscene_material.name = drawscene_name 
    

    self.materials = {
        generate_shadowmap = shadow_material,
        debug_drawDepth    = drawdepth_material,
        debug_drawScene    = drawscene_material
    }

    init_uniforms()
    -- define var userdata for set_uniform
    var_def( ctx.directionLight,"position",0,0,0,1)
    var_def( ctx.directionLight,"position_ViewSpace",0,0,0,1 )

    ctx.s_texColor = bgfx.create_uniform("s_texColor",  "i1")
    -- shadowtexture uniforms
	ctx.u_shadowMap = {
		bgfx.create_uniform("s_shadowMap0", "i1"),      -- only use for draw depth
		bgfx.create_uniform("s_shadowMap1", "i1"),
		bgfx.create_uniform("s_shadowMap2", "i1"),
		bgfx.create_uniform("s_shadowMap3", "i1"),
    }
    -- ctx.s_shadowMap {}     -- shadowtexture uniforms 
    -- ctx.shadowMapMtx{}     -- shadowMap Matrices 
    -- ctx.s_rtShadowMap{}    -- framebuffers & textures
    -- ctx.shadowMapSize      -- texture width
    -- ctx.shadowMapTexelSize -- texel size 

    -- light shadow matrices
    -- initMatrices(ctx.shadowMapMtx,4)
    uniforms.shadowMapMtx0 = ctx.shadowMapMtx[1]
    uniforms.shadowMapMtx1 = ctx.shadowMapMtx[2]
    uniforms.shadowMapMtx2 = ctx.shadowMapMtx[3]
    uniforms.shadowMapMtx3 = ctx.shadowMapMtx[4]

    -- uniforms.s_shadowMap0 = ctx.s_shadowMap[1]
    -- uniforms.s_shadowMap1 = ctx.s_shadowMap[2]
    -- uniforms.s_shadowMap2 = ctx.s_shadowMap[3]
    -- uniforms.s_shadowMap3 = ctx.s_shadowMap[4]

    -- not need,but for manually test 
    -- debug draw depth 
    ctx.state_rgba = bgfx.make_state {
        WRITE_MASK = "RGBA",
        CULL = "CCW",
        DEPTH_TEST = "ALWAYS"
	}
	ctx.PosColorTexCoord0Vertex = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
		{ "TEXCOORD0", 2, "FLOAT" },
    }
    ctx.color_tb = bgfx.transient_buffer "fffdff"
    -- d3d or ogl
    ctx.s_texelHalf = 0.5

    local comp_config = shadow_maker_entity.shadow_config     -- config
    local comp_rt = shadow_maker_entity.shadow_rt             -- render target ,runtime

    local view_rc = shadow_maker_entity.view_rect 
    local w,h = view_rc.w,view_rc.h 

    -- create shadow targets
    local shadowMapSize = comp_config.shadowMapSize;
    uniforms.shadowMapTexelSize = 1/ comp_config.shadowMapSize;
    uniforms.shadowMapSize = shadowMapSize 

    ctx.shadowMapSize = shadowMapSize 
    ctx.shadowMapTexelSize = uniforms.shadowMapTexelSize 

    comp_rt.uniforms = uniforms    
    comp_rt.shadowMapSize = shadowMapSize 
    comp_rt.shadowMapTexelSize = uniforms.shadowMapTexelSize 
    comp_rt.s_rtShadowMap = {}   
    comp_rt.shadowMapMtx = {}    
    comp_rt.s_shadowMap = {}     
    
    local fbTextures = {}
    for i = 1, comp_config.numSplits do 
        fbTextures[1] = bgfx.create_texture2d(shadowMapSize,shadowMapSize,false,1,"BGRA8","rt")
        fbTextures[2] = bgfx.create_texture2d(shadowMapSize,shadowMapSize,false,1,"D24S8","rt")
        ctx.s_rtShadowMap[i] = bgfx.create_frame_buffer( fbTextures,true)
        comp_rt.s_rtShadowMap[i] = ctx.s_rtShadowMap[i]    
        comp_rt.shadowMapMtx[i] = ctx.shadowMapMtx[i]
    end 

    uniforms.s_shadowMap0 = bgfx.get_texture( ctx.s_rtShadowMap[1] ) 
    uniforms.s_shadowMap1 = bgfx.get_texture( ctx.s_rtShadowMap[2] )
    uniforms.s_shadowMap2 = bgfx.get_texture( ctx.s_rtShadowMap[3] )
    uniforms.s_shadowMap3 = bgfx.get_texture( ctx.s_rtShadowMap[4] )
    
    -- if shadow maker entity exist ,could do shadow system ,cast shadow 
    self.is_require = true     
end 


-- shadow_maker utils 
local function splitFrustum(numSplits,near,far,splitWeight)
    local sw = splitWeight 
    local ratio = far/near 
    local numSlices = numSplits*2
    local splits = {}

    splits[1] = near
    local ff = 1
    for nn =3,numSlices,2 do 
        local si = ff/numSlices 
        local nearp = sw* near*(ratio^si) + (1-sw)*(near +(far-near)*si)
        splits[ff+1] = nearp*1.005
        splits[nn] = nearp
        ff = ff+2
    end 
    splits[numSlices] = far 
    return splits 
end 

local function worldSpaceFrustumCorners( corners, near, far, projW, projH, invViewMatrix)
    local tmp_c = {}  
    local nw = near *projW
    local nh = near *projH 
    local fw = far *projW
    local fh = far *projH
    
    local numCorners = 8

    --local temp = {}  -- opt 
    local function make_vertex(idx,w,h,d)
        -- ref mode 
        -- local vec  = math3d.ref "vector"        -- ? ref  内存是否可以自动释放，当不再引用时 ? 
        -- ms(vec,{w,h,d,1},"=")                --  已查阅源代码，是一个可以自动 gc 的 userdata,但内部idx不释放则会一直存在并增加
                                                   --  ref mark 没释放连续使用是危险的,可使用 unref, vec(nil) 两种方法释放
        -- temp[1] = w                             --  不建议使用 ref，若用必须知道ref/unref 配对释放 index
        -- temp[2] = h
        -- temp[3] = d
        -- temp[4] = 1
        -- local vec = ms(temp,"P")

        local vec = ms( {w,h,d,1},"P" )         -- remommend，temporal index 
        tmp_c[idx] = vec                        
    end 

    make_vertex(1,-nw, nh, near)
    make_vertex(2, nw, nh, near)
    make_vertex(3, nw,-nh, near)
    make_vertex(4,-nw,-nh, near)

    make_vertex(5,-fw, fh, far)
    make_vertex(6, fw, fh, far)
    make_vertex(7, fw,-fh, far)
    make_vertex(8,-fw,-fh, far )

    -- convert to world space 
    for i= 1,numCorners do 
        local t_vec = ms(invViewMatrix, tmp_c[i], "*P")           
        corners[i] = t_vec
        --// local t = ms(t_vec,"T")                                 
        --// local vec = math3d.ref "vector"
        --// ms(vec,{t[1],t[2],t[3],t[4]},"=")     -- debug view                     
        --// corners[i] = vec 
        -- tmp_c[i](nil)                            --  unref
        -- ref mode
        -- math3d.unref( tmp_c[i] )                    --  or assign(nil) it's work
    end 
    temp_c = nil 
end 

local function computeViewSpaceComponents(light,mtx)
     local rv = ms( mtx, light.position, "*P")                 
     ms( light.position_ViewSpace,rv,"=")                     
end 

-- tested control variables 
local frame = 1
local dir = 1
local function debug_lightView(lightView,lightProj,shadowMapSize)
    -- use main camera framebuffer 0 to view effect 
    local idx = 1
    local step = 60
    frame = frame + 1
    if frame >=0 and frame <step  then  idx = 1
    elseif frame >= step   and frame <2*step  then   idx = 2
    elseif frame >= 2*step and frame <3*step  then   idx = 3
    elseif frame >= 3*step and frame <4*step  then   idx = 4
    else   frame =  0   end 
    --idx = 1
    bgfx.set_view_rect(0,0,0,shadowMapSize,shadowMapSize)
    bgfx.set_view_transform(0, lightView, ms(lightProj[idx],"m") ) 
end

local function debug_use_virtual_camera()
    local camera_eye = { 40, 10, 0 }
    if(frame>20 and dir == 1 ) then dir = -1 end 
    if(frame<-60 and dir == -1 ) then dir = 1 end 
    frame = frame + 1.0*dir 
    camera_eye[3] = camera_eye[3] + frame + 40
    local camera_at = {-40,10,0}
    camera_proj = ms( { type = "mat",n = 0.1,  f = 2000 , fov = 60, aspect = ctx.width/ctx.height } , "P")
    camera_view = ms( camera_eye,camera_at,"lP")   
    print("virtual camera pos ",camera_eye[1],camera_eye[2],camera_eye[3])
    return camera_view,camera_proj 
end 

local function debug_use_virtual_light( moveable, delta )
    local deltaTime = 0.01
    ctx.timeLight = ctx.timeLight + deltaTime 

    local light_eye = {}
    
    light_eye[1]  = 100
	light_eye[2]  = 100
    light_eye[3]  = 100 
    
    if moveable then 
        light_eye[1]  = light_eye[1] + math.cos(ctx.timeLight) * delta
        light_eye[3]  = light_eye[3] + math.sin(ctx.timeLight) * delta 
    end 

    local  light_at = {0,0,0}
    return light_eye,light_at 
end 

local function collectSubmitUniforms(ctx,config)

    uniforms.activeLight = ctx.directionLight

    -- all uniforms & parameters for draw scene with shadowmap
    -- params2  - for drawDepth
    uniforms.shadowMapSize = shadowMapSize 
    uniforms.depthValuePow = config.depthValuePow                     
    uniforms.showSmCoverage = config.shadowSmCoverage and 1 or 0      -- y
    uniforms.shadowMapTexelSize = 1/ config.shadowMapSize;            -- z,texelSize

    -- params2
    uniforms.shadowMapBias   = config.shadowMapBias
    uniforms.shadowMapOffset = config.shadowMapOffset 
    uniforms.shadowMapParam0 = config.shadowMapParam0   
    uniforms.shadowMapParam1 = config.shadowMapParam1   

    -- PCF Sampler
    uniforms.ss_offsetx = config.ss_offsetx 
    uniforms.ss_offsety = config.ss_offsety 

    -- params0  - for light info 
    uniforms.u_lightPosition = uniforms.activeLight.position_ViewSpace   -- light Position in view space 
    uniforms.u_csmFarDistances =  uniforms.csmFarDistances
end 

function shadow_maker:generate_shadow( shadow_entid, select_filter )    
    -- shadow_maker entity
    local entity = world[ shadow_entid ]
    local config = entity.shadow_config 
    local shadow = entity.shadow_rt 

    shadow.ready = false     

    -- direction light entity  get light position  from light entity
    local d_light = world:first_entity("directional_light")
    --ms(ctx.directionLight.position,d_light.position,"=")
    --ms(ctx.directionLight.position_ViewSpace,d_light.position,"=")
    local d_light_dir_p = ms(d_light.rotation,"diP")
    local d_light_dir = ms(d_light_dir_p,"T")


    -- main camera entity, get main camera's position,direction
    local camera = world:first_entity("main_camera")
    local camera_view_rc = camera.view_rect 
    local camera_view, camera_proj = math_util.view_proj_matrix(camera)
    
    -- 测试指定一个相机位置
    if config.debug_virtualCamera  then 
        camera_view, camera_proj = debug_use_virtual_camera()
    end 

    -- update common 
    ctx.width   = camera_view_rc.w 
    ctx.height  = camera_view_rc.h
    ctx.projHeight  =  math.tan(math.rad(60)*0.5) 
    ctx.projWidth   =  ctx.projHeight*(ctx.width /ctx.height)

    -- submit uniforms 
    local shadowMapSize = config.shadowMapSize;
    collectSubmitUniforms(ctx,config)

    computeViewSpaceComponents(ctx.directionLight, camera_view )

    local  numSplits = 1
    if config.lightType == "DirectionLight" then 
        numSplits = config.numSplits
    end     

    local mtx_CameraViewInv = ms(camera_view,"iP")

    -- h = false => 0,1; -- h = true  => -1,1 
    -- 原来使用的
    -- local mtxProj  = ms( { type = "ortho", l=1, r=-1, b=1, t=-1, n= -config.far  , f= config.far ,h = false     },"P") -- true 距离较远，精度较低
    -- 转换成新的API
    local mtxProj = ms({type="mat", l=1, r=-1, t=-1, b=1, n=-config.far, f= config.far, ortho = true }, "P")	-- make a ortho mat
    if config.lightType == "DirectionLight" then 
        local light_eye = { 100,100,100,1}
        local light_at  = { 0,0,0,1}  
        if config.debug_virtualLight then 
            light_eye , light_at = debug_use_virtual_light( true  ,200  )
            d_light_dir[1] = light_at[1] - light_eye[1]
            d_light_dir[2] = light_at[2] - light_eye[2]
            d_light_dir[3] = light_at[3] - light_eye[3]
            local rot = ms(d_light_dir,"DP")
            --local t = ms(rot,"T")
            --print(t[1],t[2],t[3],t[4])
            ms(d_light.rotation,rot,"=")
        else
            -- get from directinal light entity 
            light_eye[1] = light_at[1] + d_light_dir[1]*100
            light_eye[2] = light_at[2] + d_light_dir[2]*100
            light_eye[3] = light_at[3] + d_light_dir[3]*100
            -- position,direction etc  
        end 

        -- 这个是赋值，还是新内存对象替代原来的 lightView[1],需要查源码对照求证?!!
        lightView[1] = ms( light_eye,light_at,"lP")    

        local splitSlices = splitFrustum( numSplits ,
                                          config.near,
                                          config.far,
                                          config.splitDistribution )          
        -- make frustum corners
        local numCorners = 8
        local nn = -1
        local ff = 0
        for i= 1,numSplits do 
            nn = nn + 2
            ff = ff + 2 
            local fc = frustumCorners[i]
            if not fc then 
                fc  = {}
                frustumCorners[i]  = fc 
            end 

            worldSpaceFrustumCorners(fc,splitSlices[nn],splitSlices[ff],ctx.projWidth,ctx.projHeight, mtx_CameraViewInv )   
            local min = { 9999,9999,9999}
            local max = { -9999,-9999,-9999}

            for j = 1, numCorners do 
                local lightSpaceCorner = ms(lightView[1], fc[j],"*P")
                local t = ms(lightSpaceCorner,"T")  
                local v1,v2,v3 = t[1],t[2],t[3] 
                min[1] = math.min(min[1],v1)
                max[1] = math.max(max[1],v1)
                min[2] = math.min(min[2],v2)
                max[2] = math.max(max[2],v2)
                min[3] = math.min(min[3],v3)
                max[3] = math.max(max[3],v3)
            end 

            local min_proj_id = ms(mtxProj, min, "*P")    
            local max_proj_id = ms(mtxProj, max, "*P")
            local min_proj = ms(min_proj_id,"T")         
            local max_proj = ms(max_proj_id,"T")

            -- 另一种方案
            -- local quant = 1/config.shadowMapSize 
            -- local qx = math.fmod( min_proj[1],quant)
            -- local qy = math.fmod( min_proj[2],quant)
            -- min_proj[1] = min_proj[1]-qx 
            -- min_proj[2] = min_proj[2]-qy 
            -- max_proj[1] = max_proj[1]-qx 
            -- max_proj[2] = max_proj[2]-qy 

            -- local scalez  = 1/(max_proj[3] - max_proj[3]);  -- could be work
            -- local offsetz = min_proj[3]*scalez; 
            local scalex = 2.0/( max_proj[1] - min_proj[1] )
            local scaley = 2.0/( max_proj[2] - min_proj[2] )           

            if config.stabilize then 
                local quantizer = config.shadowMapSize   
                scalex = quantizer/ math.ceil( quantizer/scalex )
                scaley = quantizer/ math.ceil( quantizer/scaley )
            end 

            local offsetx = 0.5 * ( max_proj[1] + min_proj[1] )* scalex 
            local offsety = 0.5 * ( max_proj[2] + min_proj[2] )* scaley
            if config.stabilize then     
                local halfSize = ctx.shadowMapSize * 0.5   
                offsetx = math.ceil(offsetx * halfSize) / halfSize
                offsety = math.ceil(offsety * halfSize) / halfSize 
            end 
            -- 只完成移动方向的snap,旋转上仍旧会抖动
            -- 尽管pcf 可以很大消除这种抖动，但理论上不带pcf 的锯齿图也可以稳定
            -- 精度的差异，offset 的差别会影响投影器的稳定性 
            local mtxCrop = ms( {
                scalex,  0,      0,   0, 
                0,       scaley, 0,   0,
                0,       0,      1,   0,
                offsetx, offsety,0,   1 }, "P" )

            lightProj[i] = ms( mtxProj, mtxCrop, "*P")   

            -- 替换合适算法或可以使得旋转也稳定 
            -- 另一种方案 
            -- local lightProjection = ms({ type = "ortho",
            --                                 l = min_proj[1],r= max_proj[1],
            --                                 t = min_proj[2],b= max_proj[2],
            --                                 n = min_proj[3],f= max_proj[3], h = fasle },"P")
            -- lightProj[i] = lightProjection;
        end 
    end 

    ----------------------------------------------------------
    -- reset render shadowmap targets 
    for  i = 1 , VIEWID_SHADOW_END do
        bgfx.set_view_frame_buffer(i)
    end 

    for  i = VIEWID_DRAWSCENE , VIEWID_DRAWDEPTH_END do
        bgfx.set_view_frame_buffer(i)
    end 

    local lightViewPtr  = ms(lightView[1],"m")                         -- id to pointer for bgfx 

    if config.lightType == "DirectionLight" then 
        bgfx.set_view_rect( VIEWID_SHADOW_START+0, 0,0,shadowMapSize,shadowMapSize)
        bgfx.set_view_rect( VIEWID_SHADOW_START+1, 0,0,shadowMapSize,shadowMapSize)
        bgfx.set_view_rect( VIEWID_SHADOW_START+2, 0,0,shadowMapSize,shadowMapSize)
        bgfx.set_view_rect( VIEWID_SHADOW_START+3, 0,0,shadowMapSize,shadowMapSize)

        bgfx.set_view_transform( VIEWID_SHADOW_START+0, lightViewPtr , ms(lightProj[1],"m") )
        bgfx.set_view_transform( VIEWID_SHADOW_START+1, lightViewPtr , ms(lightProj[2],"m") )
        bgfx.set_view_transform( VIEWID_SHADOW_START+2, lightViewPtr , ms(lightProj[3],"m") )
        bgfx.set_view_transform( VIEWID_SHADOW_START+3, lightViewPtr , ms(lightProj[4],"m") )

        bgfx.set_view_frame_buffer( VIEWID_SHADOW_START+0, ctx.s_rtShadowMap[1])
        bgfx.set_view_frame_buffer( VIEWID_SHADOW_START+1, ctx.s_rtShadowMap[2])
        bgfx.set_view_frame_buffer( VIEWID_SHADOW_START+2, ctx.s_rtShadowMap[3])
        bgfx.set_view_frame_buffer( VIEWID_SHADOW_START+3, ctx.s_rtShadowMap[4])
    end 


    if config.debug_drawLightView then 
        debug_lightView( lightViewPtr,lightProj,shadowMapSize )
    end 

    -- -- Clear backbuffer at beginning.
    bgfx.set_view_clear(0, "CD", 0x000099ff, 1, 0)
    bgfx.touch(0)
    
    -- Clear shadowmap rendertarget at beginning.
    local flags = config.lightType == "DirectionLight" and "CD" or ""  
    for i = 1, numSplits do 
        local viewId = VIEWID_SHADOW_START + i - 1
        bgfx.set_view_clear( viewId , flags , 0xfefefeff  , 1 , 0 )
        bgfx.touch( viewId )
    end 

    for i = 1,numSplits do 

        local viewId = VIEWID_SHADOW_START + i - 1
        -- do culling & render mesh
        --   notify shadow_cast_system to do culling  -- 如何每次传递不同的 frustum 
        --   exact shadow frustum culling system that we need 
        world:change_component(-1,"culling_shadow_cast_filter")   
        world:notify()

        -- update immediately,check delay 
        -- local filter = select_filter
        -- filter.result = {}
        -- for _,eid in world:each("can_render") do                   -- can_cast  
        --      if render_cu.is_entity_visible(world[eid]) then       -- vis culling 
        --          insert_shadow_primitive( eid, filter.result )
        --      end 
        -- end 
    
        --self:render_debug( entity, select_filter )
        self:render_to_texture( entity, select_filter, viewId, self.materials.generate_shadowmap )
    end 

    -- bias matrix 
    local ymul = ctx.s_flipV and 0.5 or -0.5
    local zadd = config.depthImpl == "Linear" and 0 or 0.5
    local mtxBias = ms(  {
                0.5, 0.0, 0.0, 0.0,
                0.0, ymul, 0.0, 0.0,
                0.0, 0.0, 0.5,  0.0,
                0.5, 0.5, zadd, 1.0 },"P"
            )

    for i = 1,numSplits do 
        local mtxTemp = ms( mtxBias, lightProj[i], "*P")
        ctx.shadowMapMtx[i] = ms(mtxTemp, lightView[1], "*m")
        -- ctx & comp_rt references 
        shadow.shadowMapMtx[i] = ctx.shadowMapMtx[i]
    end  

    uniforms.shadowMapMtx0 = ctx.shadowMapMtx[1]
    uniforms.shadowMapMtx1 = ctx.shadowMapMtx[2] 
    uniforms.shadowMapMtx2 = ctx.shadowMapMtx[3]
    uniforms.shadowMapMtx3 = ctx.shadowMapMtx[4]

    uniforms.s_shadowMap0 = bgfx.get_texture( ctx.s_rtShadowMap[1] )
    uniforms.s_shadowMap1 = bgfx.get_texture( ctx.s_rtShadowMap[2] )
    uniforms.s_shadowMap2 = bgfx.get_texture( ctx.s_rtShadowMap[3] )
    uniforms.s_shadowMap3 = bgfx.get_texture( ctx.s_rtShadowMap[4] )

    -- draw depth texture 
    if config.debug_drawShadow then 
        -- local screenProj = ms( { type = "ortho",l=0, r=1, b=1, t=0, n=0,f=100}, "m")
        -- convert to new api 
        local screenProj = ms({type="mat", l=0, r=1, t=0, b=1, n=0, f= 100, ortho=true }, "m")	-- make a ortho mat
        local screenView = ms( {
            1,  0, 0, 0, 
            0,  1, 0, 0,
            0,  0, 1, 0,
            0,  0, 0, 1 }, "m" )   
        -- determine on-screen rectangle where depth texture will be drawn for debug
        local depthRectHeight = math.floor(ctx.height/3 )
        local depthRectWidth = depthRectHeight
        local depthRectX = 0
        local depthRectY = ctx.height - depthRectHeight     -- bottom - height = start y
       
        -- for debug shadow 
        bgfx.set_view_rect( VIEWID_DRAWDEPTH_START+0, depthRectX+(0*depthRectWidth), depthRectY, depthRectWidth, depthRectHeight)
        bgfx.set_view_rect( VIEWID_DRAWDEPTH_START+1, depthRectX+(1*depthRectWidth), depthRectY, depthRectWidth, depthRectHeight)
        bgfx.set_view_rect( VIEWID_DRAWDEPTH_START+2, depthRectX+(2*depthRectWidth), depthRectY, depthRectWidth, depthRectHeight)
        bgfx.set_view_rect( VIEWID_DRAWDEPTH_START+3, depthRectX+(3*depthRectWidth), depthRectY, depthRectWidth, depthRectHeight)

        bgfx.set_view_transform( VIEWID_DRAWDEPTH_START + 0, screenView, screenProj  )        
        bgfx.set_view_transform( VIEWID_DRAWDEPTH_START + 1, screenView, screenProj  )        
        bgfx.set_view_transform( VIEWID_DRAWDEPTH_START + 2, screenView, screenProj  )        
        bgfx.set_view_transform( VIEWID_DRAWDEPTH_START + 3, screenView, screenProj  )        

        for i = 1, numSplits do 
            local viewId = VIEWID_DRAWDEPTH_START + i -1
            bgfx.touch( viewId )
            bgfx.set_texture( 4, ctx.u_shadowMap[1],  bgfx.get_texture( ctx.s_rtShadowMap[i] ) )
            bgfx.set_state( ctx.state_rgba )
            screenSpaceQuad( shadowMapSize,shadowMapSize, ctx.s_flipV)
            bgfx.submit( viewId, self.materials.debug_drawDepth.shader.prog )  
        end 
    end 
 
    -- render scene with shadow 
    if config.debug_drawScene then           
        bgfx.set_view_rect(VIEWID_DRAWSCENE,0,0,ctx.width,ctx.height)
        bgfx.set_view_transform(VIEWID_DRAWSCENE,ms(camera_view,"m"),ms(camera_proj,"m") )   -- (id->pointer) bgfx need pointer     
        self:render_debug_with_shadow( entity, select_filter, self.materials.debug_drawScene )
    end 

    -- if config.shadowMapSize changed then 
    -- end 
    shadow.ready = true   
    -- print(" ")
end 

local function get_shadow_properties()
    local properties = {} 

    for _,l_eid in world:each("shadow_maker") do 
        local  sm_ent   = world[l_eid]
        local  uniforms = sm_ent.shadow_rt.uniforms 
        print(" get shadow uniforms",#uniforms )
        -- local entity = world[ shadow_entid ]
        -- local config = entity.shadow_config 
        -- local shadow = entity.shadow_rt 

        properties["u_params1"] = { name = "u_params1",type="v4",value = { 0.0000015*FAR,0.20,0.5,1} }         -- ortho -far,far, h = false 
        properties["u_params2"] = { name = "u_params2",type="v4",
                                    value = { uniforms.depthValuePow,
                                              uniforms.showSmCoverage,
                                              uniforms.shadowMapTexelSize, 0 } }
        properties["u_smSamplingParams"] = { name = "u_smSamplingParams",
                                   type="v4",
                                   value = { 0, 0, uniforms.ss_offsetx, uniforms.ss_offsety } }

        -- shadow matrices 
        properties["u_shadowMapMtx0"] = { name  = "u_shadowMapMtx0", type  = "m4", value = uniforms.shadowMapMtx0 }
        properties["u_shadowMapMtx1"] = { name  = "u_shadowMapMtx1", type  = "m4", value = uniforms.shadowMapMtx1 }
        properties["u_shadowMapMtx2"] = { name  = "u_shadowMapMtx2", type  = "m4", value = uniforms.shadowMapMtx2 }
        properties["u_shadowMapMtx3"] = { name  = "u_shadowMapMtx3", type  = "m4", value = uniforms.shadowMapMtx3 }
        -- shadow textures 
        properties["s_shadowMap0"] = {  name = "s_shadowMap0", type = "texture", stage = 4, value = uniforms.s_shadowMap0 }
        properties["s_shadowMap1"] = {  name = "s_shadowMap1", type = "texture", stage = 5, value = uniforms.s_shadowMap1 }
        properties["s_shadowMap2"] = {  name = "s_shadowMap2", type = "texture", stage = 6, value = uniforms.s_shadowMap2 }
        properties["s_shadowMap3"] = {  name = "s_shadowMap3", type = "texture", stage = 7, value = uniforms.s_shadowMap3 }
    end 

    return properties 
end 


function shadow_maker:render_debug_with_shadow(shadow_entity,select_filter,material)
    local meshes = {
        { result = select_filter.result, mode =''}    --, material = self.materials.generate_shadowmap},
    }
    local view_id = shadow_entity.viewid  
    view_id  = VIEWID_DRAWSCENE 
    bgfx.touch( view_id )

    -- 注意 normal*2-1 的差别
    -- print("u_params1",uniforms.shadowMapBias ,uniforms.shadowMapOffset,
    --                  uniforms.shadowMapParam0,uniforms.shadowMapParam1 )
    -- print("u_params2",uniforms.depthValuePow,uniforms.showSmCoverage, uniforms.shadowMapTexelSize )

    for _, mq in ipairs( meshes ) do                 -- mesh queue 
        bgfx.set_view_mode(view_id, mq.mode)
        for _,prim in ipairs( mq.result) do          -- each single mesh
            prim.material = material 
             
            prim.properties =  get_shadow_properties()
            -- {
            --     -- params1 = 
            --     --self.shadowMapBias   = 0.0012    -- bias 
            --     --self.shadowMapOffset = 0.0       -- offset shadowmap (normal offset)
            --     --self.shadowMapParam0 = 0.05      -- shadowMapParam0 
            --     --self.shadowMapParam1 = 1         -- shadowMapParam1
            
            --     -- bias,offset,  shadowMapParam0，shadowMapParam1
            --     --               pcfMode ,        NoiseAmount
            --     -- 值不能传到 shader 里的参数，容易犯错的坑! 必须使用表，而不是统一使用 userdata 模式，使用 vec4 不正确,但不报错
            --     -- u_params1 = { name = "u_params1", type="v4", value = { 0.00128,1.38,0.5,1} },    -- near,far 
            --     -- 塔门木头能出现明显的阴影,背影处能有遮挡，当仍然有头部留白
            --     -- u_params1 = { name = "u_params1",type="v4",value = { 0.0005,0.75,0.5,1} },       -- ortho -far,far, 
            --     -- 0.00075 
            --     -- u_params1 = { name = "u_params1",type="v4",value = { 0.0000015*FAR*1.5,0.20,0.5,1} },   -- light 1-30 far 
            --     u_params1 = { name = "u_params1",type="v4",value = { 0.0000015*FAR,0.20,0.5,1} },         -- ortho -far,far, h = false 
            --     -- u_params1 = { name = "u_params1",type="v4",value = { 0.0000015*FAR*2,0.20*2,0.5,1} },  -- ortho -far,far, h = true 
            --     -- depthPow, SmCoverage, SmTexelSize(u_shadowMapTexelSize)
            --     -- x,        y,          z,
            --    u_params2 = { name = "u_params2",type="v4", value = { uniforms.depthValuePow,uniforms.showSmCoverage,uniforms.shadowMapTexelSize, 0 } },
            --    u_smSamplingParams = { name = "u_smSamplingParams",
            --                           type="v4",
            --                           value = { 0, 0, uniforms.ss_offsetx, uniforms.ss_offsety } },

            --     u_shadowMapMtx0 = { name  = "u_shadowMapMtx0", type  = "m4", value = uniforms.shadowMapMtx0 },
            --     u_shadowMapMtx1 = { name  = "u_shadowMapMtx1", type  = "m4", value = uniforms.shadowMapMtx1 },
            --     u_shadowMapMtx2 = { name  = "u_shadowMapMtx2", type  = "m4", value = uniforms.shadowMapMtx2 },
            --     u_shadowMapMtx3 = { name  = "u_shadowMapMtx3", type  = "m4", value = uniforms.shadowMapMtx3 },

            --     s_shadowMap0 = {  name = "s_shadowMap0", type = "texture", stage = 4, value = uniforms.s_shadowMap0 },
            --     s_shadowMap1 = {  name = "s_shadowMap1", type = "texture", stage = 5, value = uniforms.s_shadowMap1 },
            --     s_shadowMap2 = {  name = "s_shadowMap2", type = "texture", stage = 6, value = uniforms.s_shadowMap2 },
            --     s_shadowMap3 = {  name = "s_shadowMap3", type = "texture", stage = 7, value = uniforms.s_shadowMap3 },
            -- }

            local srt = prim.srt

            local mat = ms({ type="srt", s=srt.s, r=srt.r, t=srt.t}, "m")
            render_util.draw_primitive( view_id, prim, mat)

        end 
    end 
end 


function shadow_maker:render_debug(shadow_entity,select_filter)
    -- use shadow material & matrix render 
    local meshes = {
        { result = select_filter.result, mode =''}    --, material = self.materials.generate_shadowmap},
    }
    local view_id = shadow_entity.viewid           -- shadow target
    view_id = VIEWID_DRAWSCENE 
    bgfx.touch( view_id )

    for _, mq in ipairs( meshes ) do                  -- mesh queue 
        bgfx.set_view_mode(view_id, mq.mode)
        for _,prim in ipairs( mq.result) do           -- each single mesh
        local srt = prim.srt
        local mat = ms({ type="srt", s=srt.s, r=srt.r, t=srt.t}, "m")
        render_util.draw_primitive( view_id, prim, mat)        
        end 
    end 
end 

-- get render state, gpu program from shadow material
-- so prog_shadow_id, renderState not needed
function shadow_maker:render_to_texture( entity, select_filter, viewId, shadow_material  )
    -- Mesh's matrix, prim.material, prim.properties, material.state, material.shader.prog
    local meshes = {
        { result = select_filter.result, mode='', material = shadow_material },
    }
    local view_id = viewId 
    bgfx.touch( view_id )                   -- test
    for _,mq in ipairs( meshes ) do 
        for _,prim in ipairs(mq.result) do 

            local surface_type = prim.material.surface_type

             if surface_type.shadow.cast == "on" then

                local cast_prim = {}
                for k,v in pairs(prim) do 
                    cast_prim[k] = v 
                end 
                cast_prim.material = mq.material  

                cast_prim.properties = { }
            
                -- state & program assign by input material 
                local srt = cast_prim.srt 
                local mat = ms( { type="srt", s=srt.s, r=srt.r, t=srt.t}, "m")
            
                -- debug output to framebuffer main camera viewid
                render_util.draw_primitive( view_id, cast_prim, mat)
                --print("do check generate shadow")
            end 
        end 
    end 

end     

-- 调试显示 shadowmap
function shadow_maker:debug_drawshadow()

end 


-----------------------------------------
-- 测试 culling 是否同步，有没有滞后的
-- 网格加入到剪裁结果列表 filter.result ，而后使用 shadow_material 进行渲染
local function insert_shadow_primitive(eid, result)
	local entity = world[eid]

	local mesh = assert(entity.mesh.assetinfo)
	
	local materialcontent = entity.material.content
	assert(#materialcontent >= 1)

	local srt ={s=entity.scale, r=entity.rotation, t=entity.position}
	local mgroups = mesh.handle.groups
	for i=1, #mgroups do
		local g = mgroups[i]
		local mc = materialcontent[i] or materialcontent[1]
		local material = mc.materialinfo
		local properties = mc.properties

		table.insert(result, {
			eid = eid,
			mgroup = g,
			material = material,
			properties = properties,
			srt = srt,
		})
	end
end
--------------------------------------------------------
-- filter component & system 
--    声明一个 shadow_cast_filter 组件类型
--    定义组件初始化函数，初始化组件内部结构-剪裁结果表
-- shadow_cast_filter
local shadow_cast_filter = ecs.component_struct "shadow_cast_filter" {}
function shadow_cast_filter:init()
    self.result = {}
end 

-- shadow_cast_system 
local shadow_filter_system = ecs.system "shadow_cast_system"
shadow_filter_system.singleton "shadow_cast_filter"               -- single component global
-- 阴影网格剪裁系统也是 shadow_system 的一个子系统
-- 可以如下作为一个成对的子系统同步运行
-- function shadow_filter_system:update()
--     local filter = self.shadow_cast_filter
--     filter.result = {}
--     for _,eid in world:each("can_render") do                   -- can_cast  
--         if render_cu.is_entity_visible(world[eid]) then   -- vis culling 
--             insert_shadow_primitive( eid, filter.result )
--         end 
--     end 
-- end 

-- 由 shadow_system generate 函数驱动，收集light frustum 中的可投掷阴影mesh
-- 不知道执行序和效率是否有影响 ?
function shadow_filter_system.notify:culling_shadow_cast_filter()
    local filter = self.shadow_cast_filter
    filter.result = {}
    for _,eid in world:each("can_render") do              -- can_cast, mesh 需要新增 can_cast 属性
        if render_cu.is_entity_visible(world[eid]) then   -- vis culling 
            insert_shadow_primitive(eid,filter.result)
        end 
    end 
end 



------------------------------------------------------
-- generate shadow main system 
local gen_shadow_system = ecs.system "generate_shadow_system"

gen_shadow_system.singleton "shadow_cast_filter"
gen_shadow_system.depend   "view_system"       
gen_shadow_system.dependby "lighting_primitive_filter_system"
gen_shadow_system.dependby "entity_rendering" 

function gen_shadow_system:init()
    local function add_shadow_maker_entity()
        local eid = world:new_entity(
            "shadow_maker",             -- test combine
            "shadow_config","shadow_rt",
            "viewid", "view_rect", "frustum",
            "clear_component",
            "position","rotation",
            "name")
        local entity = assert( world[eid] )
        entity.viewid = VIEWID_SHADOW 
        entity.name = "shadowmap_maker"            

        local shadow_maker_comp = entity.shadow_maker

        -- view and frustum, not need 
        local view_rc = entity.view_rect;
        view_rc.w = SHADOWMAP_SIZE;
        view_rc.h = SHADOWMAP_SIZE;
        local light_frustum = entity.frustum 
        math_util.frustum_from_fov(light_frustum,0.1,1000,1,view_rc.w/view_rc.h)

        -- get light' position,direction 
        -- light 灯光应该在具备是否 is_cast_shadow 的属性
        -- 这个通过修改 light.component attrib 来扩充
        local pos = entity.position
        local rot = entity.rotation 
        -- directional_light 的 entity 添加次序不确定，可能比generate 晚
        -- 需要最后确定下执行顺序，确保正确流程 
        -- local sun = world:first_entity("directional_light")  
        -- rot = sun.direction;
        -- pos = sun.pos
        return entity
    end 

    local entity = add_shadow_maker_entity()

    -- 阴影生成器初始化,具体行为打包在一个类里，简化 shadow system 
    -- shadow_maker 通过 shadow_maker entity 查询数据，执行动作    

    shadow_maker:init( entity )   
end

-- shadow_maker 
--  可以扩充 shadow_maker 功能，使用不同的剪裁系统
--  独立成辅助函数类
function gen_shadow_system:update()
    if shadow_maker.is_require then 
        -- local shadow_entid = world:first_entity("shadow_rt")
        local shadow_entid = world:first_entity_id("shadow_maker")
        shadow_maker:generate_shadow(shadow_entid, self.shadow_cast_filter ) 
    end 
    shadow_maker:debug_drawshadow()
end



-- 修改 mesh 渲染函数
-- render mesh (submitMesh)                   -- render mesh without shadow
-- render mesh shadow (submitShadow)          -- for generate shadow
-- render mesh with shadow (submitShadowMesh) -- for render mesh with shadow
-- MeshRender,TerrainRender System 对应增加 submitShadow，submitShadowMesh 函数
-- 以支持使用网格的阴影生成，网格与阴影一起渲染等功能

-- 生成阴影
-- submitShadow(viewId,matrix,mesh,material,state)                    -- 阴影生成的替代好修改,新的shader
-- 渲染网格
-- submitShadow(viewId,matrix,mesh,native material,state,withshadow)  -- 修改原来的shader，支持shadow 


-- system 不是加载顺序执行的，以不确定的顺序
-- 如果两个system 想明确的前后次序执行，必须明确指定 depend 
