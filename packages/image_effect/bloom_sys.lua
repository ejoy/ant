local ecs = ...
local world = ecs.world

local fs = require 'filesystem'
local math3d = import_package "ant.math"
local ms = math3d.stack

ecs.import 'ant.render'
ecs.import 'ant.math.adapter'
ecs.import 'ant.asset'

local bgfx  = require "bgfx"
local assetmgr = import_package "ant.asset".mgr
local fs = require 'filesystem'

local renderpkg = import_package 'ant.render'
local renderutil= renderpkg.util
local viewidmgr = renderpkg.viewidmgr
local computil  = renderpkg.components
local default_comp = renderpkg.default 
local lu = renderpkg.light


local rts = ecs.component "render_targets"
	.frame_buffers "frame_buffer[]"
	.num_targets "int" (1)
	
function rts:init()
	return self
end

function rts:delete()
end	

local bf = ecs.component "bloom"
	.blur_size  "int" (7)
	.blur_strength "real" (2.75)
	.blur_iters "int" (1)
	.blur_spread "real" (1)
	.framebuffer_size "int" (2)
	.num_targets "int" (2)
	.view_ids "int[]"
	.render_targets "render_targets"
	
function bf:init()
	return self
end 

function bf:postinit()
	assert(self.num_targets == #self.render_targets.frame_buffers);

end 


local bloom_sys = ecs.system 'bloom_sys'
bloom_sys.depend 	  'render_system'
bloom_sys.dependby    "end_frame"

local ctx = {}
ctx.state_rgba = bgfx.make_state {
    WRITE_MASK = "RGBA",
    CULL = "CCW",
    DEPTH_TEST = "ALWAYS"
}
ctx.PosColorTexCoord0Vertex = bgfx.vertex_layout {
    { "POSITION", 3, "FLOAT" },
    { "TEXCOORD0", 2, "FLOAT" },
}
ctx.color_tb    = bgfx.transient_buffer "fffff"
ctx.s_texelHalf = 0

--{ "COLOR0", 4, "UINT8", true },
--ctx.color_tb    = bgfx.transient_buffer "fffdff"


local function MakeScreenSpaceQuad( textureWidth,textureHeight, originBottomLeft)
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

	-- ctx.color_tb:packV(0, minx, miny, zz, 0x00000000, minu, minv)
	-- ctx.color_tb:packV(1, maxx, miny, zz, 0x00000000, maxu, minv)
	-- ctx.color_tb:packV(2, maxx, maxy, zz, 0x00000000, maxu, maxv)

	ctx.color_tb:packV(0, minx, miny, zz,  minu, minv)
	ctx.color_tb:packV(1, maxx, miny, zz,  maxu, minv)
	ctx.color_tb:packV(2, maxx, maxy, zz,  maxu, maxv)

	ctx.color_tb:set()
end 

local function DrawQuad(viewId,fbo,w,h,ctx)
	local screenProj = ms( {type="mat", l=0, r=1, t=0, b=1, n=0, f= 100, ortho=true }, "P")	
	local screenView = ms( {
			1,  0, 0, 0, 
			0,  1, 0, 0,
			0,  0, 1, 0,
			0,  0, 0, 1 }, "P" )   

	local QuadViewId   = viewId 
	--bgfx.set_view_clear(QuadViewId, "CD", 0x000000ff, 1, 0)
    bgfx.set_view_rect( QuadViewId, 0,0, w,h)
	bgfx.set_view_transform( QuadViewId, screenView, screenProj  )   
	bgfx.set_view_frame_buffer( QuadViewId,fbo )     
	bgfx.touch( QuadViewId )
	
	local mat = ctx.mat
	for k,v in pairs(mat.shader.uniforms) do
		local u = mat.shader.uniforms[k]
		if u.type == 's' then 
			--bgfx.set_texture( mat.properties.textures[k].stage, u.handle , ctx.texIds[k].handle )
			bgfx.set_texture( mat.properties.textures[k].stage, u.handle , ctx.args.textures[k].handle)  
		else
			--bgfx.set_uniform( u.handle,  ctx.uniforms[k])
			bgfx.set_uniform( u.handle,  ctx.args.uniforms[k].value)  
		end 
	end 
    
    bgfx.set_state( ctx.state_rgba )
    MakeScreenSpaceQuad( w,h, ctx.s_flipV)
    bgfx.submit( viewId, mat.shader.prog)  
end     

ecs.tag "bloom_ef"

function create_bloom_target(world, view_rect)
	local fb_renderbuffer_flag = renderutil.generate_sampler_flag {
		RT="RT_ON",
		MIN="LINEAR",
		MAG="LINEAR",
		U="CLAMP",
		V="CLAMP",
    }
	
	local bloom_ent = world:create_entity {
		bloom = {
			blur_size = 5 ,
			blur_strength = 3.25,
			blur_spread = 1.8,
			blur_iters = 1,
			framebuffer_size = 256,
			num_targets = 2,
			view_ids = {
				viewidmgr.get("pingpong_view_s"),
				viewidmgr.get("pingpong_view_e"),
			},
			render_targets = {
				frame_buffers = {
					{
						render_buffers = {
							default_comp.render_buffer(view_rect.w, view_rect.h, "RGBA16F", fb_renderbuffer_flag),
						},
					},
					{
						render_buffers = {
							default_comp.render_buffer(view_rect.w, view_rect.h, "RGBA16F", fb_renderbuffer_flag),
						},
					},
				},
			},
		},
		material = {
			--{ref_path = fs.path "/pkg/bloom/assets"/"material/blur.material"},
			--{ref_path = fs.path "/pkg/bloom/assets"/"material/bloom.material"},
			{ref_path = fs.path "/pkg/ant.resources"/"materials/bloom/blur.material"},
			{ref_path = fs.path "/pkg/ant.resources"/"materials/bloom/bloom.material"},
		},

		visible = false,
		bloom_ef = true,
    }	
	return world[bloom_ent]
end

function table_deepcopy( source )
	local source_type = type(source)
	local inst
	if source_type == 'table' then
		inst = {}
		for key, value in pairs(source) do
			inst[table_deepcopy(key)] = table_deepcopy(value)
		end
	else 
		inst = source
	end
	return inst 
end

function bloom_sys:init()
	-- local bloom_ent = create_bloom_target(world,{w=math.ceil(256),h=math.ceil(256)} )
	-- ctx.mat_blur	= assetmgr.get_resource(bloom_ent.material.ref_path)
	-- ctx.mat_bloom 	= assetmgr.get_resource(bloom_ent.material[1].ref_path) 
end

function bloom_sys:update()
	local mq  	 = world:first_entity("main_queue")
	assert(mq,"need main_queue")
	local main_tex  = mq.render_target.frame_buffer.render_buffers[1]
	local bloom_tex = mq.render_target.frame_buffer.render_buffers[3]
	--bloom_tex = nil
	-- remove render_buffers[3] will reduce bandwith,but lost accurate 
	bloom_tex = bloom_tex or main_tex 
	assert(bloom_tex,"need main_queue with render_buffers[3]{RGBA16F} or render_buffers[1]{RGBA8} ")

	local rt_mq  = mq.render_target
	local w,h    = rt_mq.viewport.rect.w,rt_mq.viewport.rect.h

	local bloom_ent = world:first_entity("bloom_ef")
	if bloom_ent == nil then 
		bloom_ent = create_bloom_target(world,{w=math.ceil(w/2),h=math.ceil(h/2)} )
		ctx.mat_blur	= assetmgr.get_resource(bloom_ent.material.ref_path)
		ctx.mat_bloom 	= assetmgr.get_resource(bloom_ent.material[1].ref_path) 
	end  
    -- [[
	local bloom_comp   = bloom_ent.bloom 
	local rts    	   = bloom_comp.render_targets
	local blur_viewid_s = bloom_comp.view_ids[1]
	local blur_viewid_e = bloom_comp.view_ids[2]
	local rw,rh  	    = rts.frame_buffers[1].render_buffers[1].w, 
				   	      rts.frame_buffers[1].render_buffers[1].h 
	local blur_handle1 = rts.frame_buffers[1].handle 
	local blur_handle2 = rts.frame_buffers[2].handle 

	ctx.mat  = ctx.mat_blur 
	ctx.args = ctx.mat_blur.properties;
	local blur_tex   = bloom_tex 
	local blur_iters = bloom_comp.blur_iters  
	local blur_size  = bloom_comp.blur_size 
	local blur_strength = bloom_comp.blur_strength 
	local blur_spread = bloom_comp.blur_spread
	local iw,ih  = 1/rw,1/rh

	-- blur_iters = 2
	-- blur_size = 5
	-- blur_strength = 3.75,3.25
	-- blur_spread = 1
	local ping_viewid,pong_viewid
	for i=1,blur_iters do 
			ping_viewid = (i-1)*2 + blur_viewid_s
			if ping_viewid >= blur_viewid_e then 
				break 
			end 
			
			ctx.args.textures["s_basecolor"].handle = blur_tex.handle
			ctx.args.uniforms.u_params.value[1] = 1
			ctx.args.uniforms.u_params.value[2] = blur_spread
			ctx.args.uniforms.u_params.value[3] = iw
			ctx.args.uniforms.u_params.value[4] = ih 
			ctx.args.uniforms.u_blur.value[1] = blur_size
			ctx.args.uniforms.u_blur.value[2] = blur_strength
			ctx.args.uniforms.u_blur.value[3] = 0
			ctx.args.uniforms.u_blur.value[4] = 0 
			DrawQuad( ping_viewid, blur_handle1, rw, rh, ctx)
			blur_tex = rts.frame_buffers[1].render_buffers[1]

			pong_viewid = ping_viewid + 1
			ctx.args.textures["s_basecolor"].handle = blur_tex.handle
			ctx.args.uniforms.u_params.value[1] = 0
			ctx.args.uniforms.u_params.value[2] = blur_spread
			ctx.args.uniforms.u_params.value[3] = iw
			ctx.args.uniforms.u_params.value[4] = ih 
			ctx.args.uniforms.u_blur.value[1] = blur_size
			ctx.args.uniforms.u_blur.value[2] = blur_strength
			ctx.args.uniforms.u_blur.value[3] = 0
			ctx.args.uniforms.u_blur.value[4] = 0 

			DrawQuad( pong_viewid, blur_handle2, rw, rh, ctx) 
			blur_tex = rts.frame_buffers[2].render_buffers[1]
	end 

	local blur_tex1 = rts.frame_buffers[1].render_buffers[1]
	local blur_tex2 = rts.frame_buffers[2].render_buffers[1]

    local viewid = viewidmgr.get("bloom_view")
	ctx.mat      = ctx.mat_bloom
	ctx.args     = ctx.mat_bloom.properties;
	ctx.args.textures["s_basecolor"].handle = main_tex.handle 
	ctx.args.textures["s_bloomcolor"].handle = blur_tex2.handle 
	ctx.args.uniforms.u_params.value[1] = 0
	ctx.args.uniforms.u_params.value[2] = 1
	ctx.args.uniforms.u_params.value[3] = 2
	ctx.args.uniforms.u_params.value[4] = 0 
	DrawQuad( viewid, rt_mq.frame_buffer.handle, w, h, ctx )
end 
 