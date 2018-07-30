local lterrain = require 'lterrain'
local uclass = require 'utilclass'
local texLoad = require "utiltexture"
local bgfx = require "bgfx"
--local bgfxu = require "bgfx.util"

local shaderMgr = require "render.resources.shader_mgr"
local math3d = require "math3d"
local mathu = require "math.util"

local math3d_stack = math3d.new()

local readfile = function( fname )
	local f = assert(io.open( fname,'rb'))
	local d = f:read('*a')
	f:close()
	return d 
end 

------ 定义 Terrain 类 -----
local Terrain = Class("antTerrain")

-- Class Owner
-- Terrain.render_ctx = {}                  -- render relative
-- Terrain.render_ctx.vbh = 0
-- Terrain.render_ctx.ibh = 0
-- Terrain.render_ctx.prog = 0
-- Terrain.render_ctx.uniforms = {} 
-- Terrain.render_ctx.uniform_values = {} 
-- Terrain.render_ctx.tex_chanel = {}
-- Terrain.transform = {}   				-- rst terrain's pos/rot/scl
-- Terrain.bbox = {}        				-- terrain's bounding box 
-- Terrain.level = {} 						-- level info 

-- uniforms tested begin
function create_uniforms(obj)
	obj:create_uniform("u_mask","s_maskTexture","i1")
	obj:create_uniform("u_base","s_baseTexture","i1")
	obj:create_uniform("u_lightIntensity","s_lightIntensity","v4")
	obj:create_uniform("u_lightColor","s_lightColor","v4")
 end 
 
 function set_unforms(obj)
	 obj:set_uniform("u_lightIntensity",{1.8,0,0,0} )
	 obj:set_uniform("u_lightColor",{1,1,1,0.625} )
 end 
 -- uniforms tested end


function Terrain:set_transform( args )
	local args = args or {
		t = {0,0,0,1},
		r = {0,0,0,0},
		s = {1,1,1,1}
	}
	-- todo: convert to matrix 
	self.transform = math3d_stack( args.t,args.r,"dLm" )
end 	

-- name = "renamed_uniform",s_name = "s_uniform",type = "il" or "v4" etc 
function Terrain:create_uniform(name,s_name,type,texchannel)
	self.render_ctx.uniforms[name] = bgfx.create_uniform(s_name,type)
	if texchannel ~= nil then 
		self.render_ctx.tex_chanel[name] = texchannel 
	end 
	print("create uniform.. "..name.."..handle.."..self.render_ctx.uniforms[name])
end 

function Terrain:set_uniform(name,value)
	self.render_ctx.uniform_values[name] = value 
	-- bgfx.set_uniform(self.render_ctx.uniforms[name],value )
end 

function Terrain:load_program( vs,fs )
	-- sample shader 
	-- shader src     D:\Work\ant\assets\shaders\src\terrain\*.sc
	-- shader dst bin  D:\Work\ant\assets\shaders\dx11\terrain\*.bin
	self.render_ctx.prog = shaderMgr.programLoad(vs,fs) 
end 

function Terrain:set_program( prog_handle )
	self.render_ctx.prog = prog_handle 
end 

-- 材质独立成一个文件，可替换更好
-- 还是类似 unity 将terrain data，textures 合成在 Level 文件里，material(shader) 对用户不可见 ?
-- 试图提供尽可能的配置变化，不需要通过程序指定shader 内容
function Terrain:load_meterial( mtlname )
	-- todo: 
	-- load program from mtl 
	-- load textures from mtl
	-- laod uniforms from mtl
	local data = readfile( mtlname )
	local mtldata = "local mtl ="..data.." return mtl" 
	self.mtl = load( mtldata )()                			-- 如果地形管卡配置文件的内容出现错误，如何防止挂起？

	-- check program 
	self.render_ctx.prog = shaderMgr.programLoad(self.mtl.vs,self.mtl.fs)
	-- check uniforms 
	for _,o in ipairs(self.mtl.uniforms) do 
		local name,s_name,type,texchannel 
		for k,v in pairs(o) do 
			if k == "name" then 					   -- uniform name in program
				name = v 
			elseif k== "s_name" then                   -- uniform name in shader source 
				s_name = v 
			elseif k == "type" then                    
				type = v 
			elseif k == "texchannel" then 
				texchannel = v 
			end 
		end
		self:create_uniform(name,s_name,type,texchannel)
    end 
	-- check uniform values
	for k,v in pairs(self.mtl.uniform_values) do 
	 	self.render_ctx.uniform_values[k] = v 
	end 
end 


-- 顶点定义可以更开放，可以选择属性内容
-- 默认提供一个基本合适的顶点属性集合，具备POS,NORMAL,TEX0,TEX1
-- 用户可以定义更少属性，只有Pos; 或更多的属性，比如 Tangent 等信息
function  Terrain:create_vdecl( args )
    local args = args  or  {
				{"POSITION",3,"FLOAT"},   -- default attrib
				{"NORMAL",3,"FLOAT"},     -- or UINT8
				{"TEXCOORD0",2,"FLOAT"},  
				{"TEXCOORD1",2,"FLOAT"},
			  	--{"TANGENT",3,"FLOAT"},  -- or  UINT8
	}
	self.render_ctx.vdecl = bgfx.vertex_decl( args )
end 

-- level 关卡文件配置信息
-- data  地形数据几何信息，编辑信息
-- args = terrain level info 
function Terrain:init(args)      
	local args = args or { }     
	local default = {            -- default terrain level,create new terrain
		raw = "newterrain1",     -- 默认新建地形参数，需要考虑为以后编辑器预留初始数据接口   
		bits = 8,
		grid_width = 257,
		grid_length= 257,
		width  = 257,
		length = 257,
		height = 300,
		numlayers = 0,
		textures = {},
		masks = {},
		uv0_scale = 50,
		uv1_scale = 1,
	}

	-- private
	self.render_ctx = {} 
	self.render_ctx.vbh = 0
	self.render_ctx.ibh = 0
	self.render_ctx.prog = 0
	self.render_ctx.uniforms = {} 
	self.render_ctx.uniform_values = {} 
	self.render_ctx.tex_chanel = {}
	self.rst = {}
	self.transform = {}   				-- rst terrain's pos/rot/scl
	self.bbox = {}        				-- terrain's bounding box 
		
	-- setting 
	self.level = {}
	self.level.raw = args.raw or default.raw 
	self.level.bits = args.bits or default.bits 
	self.level.grid_width = args.grid_width or default.grid_width 
	self.level.grid_length = args.grid_length or default.grid_length 
	self.level.width = args.width or default.width
	self.level.length = args.length  or default.length 
	self.level.height = args.height or default.height 
	self.level.numlayers = args.numlayers or default.numlayers 
	self.level.textures = args.textures or default.textures 
	self.level.masks = args.masks or default.masks 
	self.level.uv0_scale = args.uv0_scale or default.uv0_scale
	self.level.uv1_scale = args.uv1_scale or default.uv1_scale

	-- handle default 
	self.numlayers = 0
	self.textures = {}
	self.masks = {}
	self.heightmap = {}

	-- move to render_ctx 
	-- self.prog = 0
	-- self.uniforms = {} 

    -- default transform 
	self:set_transform()
end 


-- asset
-- load terrain level,[vertex_decl]
-- return terrain data context
function Terrain:load( filename,vertex_decl )
	local data = readfile(filename)
	local lvldata = "local level ="..data.." return level" 
	self.level = load( lvldata )()                		-- 如果地形管卡配置文件的内容出现错误，如何防止挂起？
	self:create( self.level,vertex_decl )
end 


function Terrain:loadHeightmap( raw )
	self.heightmap = readfile(self.level.raw)
	return self.heightmap 
end 

-- create terrain data 
function Terrain:create( args,vertex_decl )

    local args = args or self.level   

	print('---------------create terrain context data begin --------------')
	if args.raw then 
		self.heightmap = self:loadHeightmap( self.level.raw )
	end 

    if  args.numlayers then 
		self.numlayers = args.numlayers 
	end 
	for i=1,args.numlayers,1  do
		-- print( 'tex'..i..' = '..args.textures[i])
		-- print( 'mask'..i..' = '..args.masks[i])
		self.textures[i] = texLoad( args.textures[i] )
		self.masks[i] = texLoad( args.masks[i] )
	end 
	self:create_vdecl( vertex_decl )
	self.data  = lterrain.create(self.heightmap,args,self.render_ctx.vdecl)
	self.vbo   = self.data:allocVB()
	self.ibo   = self.data:allocIB()
	print('---------------create terrain context data end --------------')

	print("create mesh begin")
	lterrain.update_mesh( self.data,self.vbo,self.ibo) 
	print("create mesh ok")

	local num = self.data:getNumVerts()
	self.render_ctx.vbh = bgfx.create_dynamic_vertex_buffer( num, self.render_ctx.vdecl );
	bgfx.update(self.render_ctx.vbh,0,{'!',self.vbo} )
	print("get vertex count = "..num)
	print("    generate handle vbh = "..self.render_ctx.vbh)

	num = self.data:getNumIndices()
	self.render_ctx.ibh = bgfx.create_dynamic_index_buffer( num,"rwd" ) --,"rwd")
	bgfx.update(self.render_ctx.ibh,0,{self.ibo})
	print("get index count = "..num)
	print("    generate handle ibh = "..self.render_ctx.ibh)
	-- print("---- create bgfx vbh,ibh handle ok ----")
end 

function Terrain:update( eye,dir)
	lterrain.update( self.data,self.vb,self.ib,eye,dir)
	self.eye = eye 
	self.dir = dir 
	-- further todo:

end 

function Terrain:get_height( x,z) 
	return  lterrain.get_height( self.data,x,z)
end 

function Terrain:render(w,h,prim_type )

	-- local srt = { t= self.eye or {0,130,-10,1},
	--               r= self.dir or {25,45,0,0},
	-- 			  s= {1,1,1,1} }          								 -- for terrain ,eye,target
	-- 																	 -- yaw = 45,	pitch = 25
	-- -- local srt = { t= {0,30,-10,1},r={0,45,0,0},s= {1,1,1,1} }          -- for terrain ,eye,target
	-- local proj_mtx = math3d_stack( { type = "proj",n=0.1, f = 1000, fov = 60, aspect = w/h } , "m")  
	-- local view_mtx = math3d_stack( srt.t,srt.r,"dLm" )    			     -- math3d_statck( op data 1,2,..,"op code string")

	-- bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	-- bgfx.set_view_rect(0, 0, 0, w, h)
	-- bgfx.reset(w,h, "vmx")
	-- bgfx.touch(0)

	-- bgfx.set_view_transform(0,view_mtx,proj_mtx)

	local prim_type = prim_type or  nil -- "LINES" --
	local state =  bgfx.make_state({ CULL="CW", PT = prim_type ,
									 WRITE_MASK = "RGBAZ",
									 DEPTH_TEST	= "LEQUAL"
								   } , nil)        									-- for terrain
	bgfx.set_state(state)

	local state_af =  bgfx.make_state({ CULL="CW", PT = prim_type ,
										 WRITE_MASK = "RGBA",
										 BLEND = "ALPHA",
										 DEPTH_TEST	= "LEQUAL"
										} , nil)        							-- for terrain

	--bgfx.set_transform( terrain_mtx )
	for i=1,self.numlayers do 
	   bgfx.set_transform(self.transform)
	   if i > 1 then bgfx.set_state(state_af) end
	    -- textures
	    --bgfx.set_texture(0,self.render_ctx.uniforms.u_base,self.textures[i].handle)
	    --bgfx.set_texture(1,self.render_ctx.uniforms.u_mask,self.masks[i].handle)       -- 不带mimap 的dds,默认最好是 REPEAT,而不是CLAMP
		--self:set_uniform("u_lightColor",{1,0,0,1} )
		--self:set_uniform("u_lightIntensity",{1.8,0,0,0})
		 
	   for k,u in pairs(self.render_ctx.uniforms) do 
		   local tex_chanel = -1
		   if self.render_ctx.tex_chanel[k] ~=nil and self.render_ctx.tex_chanel[k] >=0   then    -- texture channel
				tex_chanel = self.render_ctx.tex_chanel[k]
				if tex_chanel == 0 then 
					bgfx.set_texture( tex_chanel,self.render_ctx.uniforms[k], self.textures[i].handle)
				else 
					bgfx.set_texture( tex_chanel,self.render_ctx.uniforms[k], self.masks[i].handle)
				end 
		   else 
				bgfx.set_uniform(self.render_ctx.uniforms[k],self.render_ctx.uniform_values[k] )  -- normal uniforms 
		   end 
	   end 

 	   bgfx.set_vertex_buffer( self.render_ctx.vbh )
	   bgfx.set_index_buffer( self.render_ctx.ibh )     							 -- 使用 index 不正常显示？ wrong update api usage
	   bgfx.submit(0,self.render_ctx.prog)
	end 

	bgfx.dbg_text_clear()
	bgfx.dbg_text_print(0, 1, 0xf, "Lua \x1b[9;mt\x1b[10;me\x1b[11;mr\x1b[12;mr\x1b[13;ma\x1b[14;mi\x1b[0mn API test.");

end 

local ctx = {} 
local CUBE_TEST = 0
function Terrain:render_test( w,h  )
	--print("w := "..w.." h := "..h)
	--print(w/h)
	lterrain.render( self.data )

	local frustum = {} 
	mathu.frustum_from_fov(frustum, 0.1, 1000, 60, w / h)
	local proj_mat = mathu.proj_v(math3d_stack, frustum)

	local view_mat = math3d.ref "matrix"  
	view_mat(t,{0,20,-10,1},"=")
	view_mat(r,{0,45,0,0},"=")
	view_mat(s,{1,1,1,1},"=")

	-- 必须在函数前，写明参数，个数，字符串表示参数意义，用法，否则，需要太多时间查询过多的关联函数和文件
	-- math_stack(op data1,op data2,..."op code string")
	local srt = { t= {0,130,-10,1},r={25,45,0,0},s= {1,1,1,1} }          -- for terrain ,eye,target
																		   -- yaw = 45,	pitch = 25
    --local srt = { t= {0,30,-10,1},r={0,45,0,0},s= {1,1,1,1} }              -- for terrain ,eye,target
	--local srt = { s={1,1,1},r={0,0,0,1},t={0,1,-10,1} }       		   -- fro cube 
	local proj_mtx = math3d_stack( { type = "proj",n=0.1, f = 1000, fov = 60, aspect = w/h } , "m")  
	local view_mtx = math3d_stack( srt.t,srt.r,"dLm" )   -- math3d_statck( op data 1,2,..,"op code string")
															   -- view_system.lua 
															   -- L generate lookat,d convert rot to dir
															   -- m pop matrix pointer 
															   -- for cube 

	-- test2
    local mtx = math3d_stack( {0,20,-10,1},{0,45,0,0},"lP")         -- lookat matrix 
	local mat = math3d.ref "matrix"	
	math3d_stack(mat,"1=")
	mat(mtx)
	--view_mtx = mat 

    -- test3
	-- proj_mtx = proj_mat       -- add far plane from frustum ok
	-- view_mtx = view_mat       -- view from math3d.ref ,error ?

	--print("proj_mtx: ")
	--print(proj_mtx)
	--print("view_mtx: ")
	--print(view_mtx)

	local srt1 = { s={2,2,2},r={0,40,0,0},t={100,60,100,1} }
	local obj_mtx = math3d_stack( srt1.t,srt1.r,"dLm" )

	--local vv = math3d_stack({1, 2, 3, 1}, {2}, "*V")
	--print("vec4 mul : " .. vv)
	--local vec = math3d.ref "vector"
	--math3d_stack( vec, { 1,2,3,4 } , "1+=")

   --[[
	local proj = math3d.ref "matrix"
	local view = math3d.ref "matrix"
	math3d_stack ( proj,"1=")
	math3d_stack ( view,"1=")
	]]

	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	bgfx.touch(0)


	bgfx.dbg_text_clear()
	bgfx.dbg_text_print(0, 1, 0xf, "lua \x1b[9;mt\x1b[10;me\x1b[11;mr\x1b[12;mr\x1b[13;ma\x1b[14;mi\x1b[0mn API test.");


	if CUBE_TEST == 0 then 
		ctx.width  = w
		ctx.height = h
		ctx.prog   = shaderMgr.programLoad("vs_cubes", "fs_cubes")

		ctx.state = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- from BGFX_STATE_DEFAULT
		ctx.vdecl = bgfx.vertex_decl {
			{ "POSITION", 3, "FLOAT" },
			{ "COLOR0", 4, "UINT8", true },
		}
		ctx.vb = bgfx.create_vertex_buffer({
				"fffd",
				-1.0,  1.0,  1.0, 0xff000000,
				1.0,  1.0,  1.0, 0xff0000ff,
				-1.0, -1.0,  1.0, 0xff00ff00,
				1.0, -1.0,  1.0, 0xff00ffff,
				-1.0,  1.0, -1.0, 0xffff0000,
				1.0,  1.0, -1.0, 0xffff00ff,
				-1.0, -1.0, -1.0, 0xffffff00,
				1.0, -1.0, -1.0, 0xffffffff,
			},
			ctx.vdecl)
		ctx.ib = bgfx.create_index_buffer{
			0, 1, 2, 3, 7, 1, 5, 0, 4, 2, 6, 7, 4, 5,
		}

		print("cube vb = "..ctx.vb)
		print("cube ib = "..ctx.ib)
		CUBE_TEST = 1
	end 

	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.reset(w,h, "vmx")
	bgfx.set_view_transform(0,view_mtx,proj_mtx)

	if CUBE_TEST == 1 then 
		local state = bgfx.make_state { CULL = "CW",PT = "TRISTRIP", }
		bgfx.set_state(state)
		--bgfx.set_transform( obj_mtx )
		bgfx.set_vertex_buffer(ctx.vb)
		bgfx.set_index_buffer(ctx.ib)
		bgfx.submit(0, ctx.prog)
		--bgfx.submit(0,self.render_ctx.prog)
	end 

	   ---[[ terrain 
	   local prim_type = "LINES" -- nil -- 
	   local state =  bgfx.make_state({ CULL="CW", PT = prim_type ,
	   						 			WRITE_MASK = "RGBAZ",
										DEPTH_TEST	= "LEQUAL"
									  } , nil)        									-- for terrain
					  --bgfx.make_state ( { CULL = "CW",PT = "TRISTRIP"},nil )      	-- for cube 
	   bgfx.set_state(state)

	   local state_af =  bgfx.make_state({ CULL="CW", PT = prim_type ,
									    	WRITE_MASK = "RGBA",
											BLEND = "ALPHA",
											DEPTH_TEST	= "LEQUAL"
 									  	} , nil)        								-- for terrain

	   --bgfx.set_transform( obj_mtx )
	   for i=1,self.numlayers do 
		  if i > 1 then bgfx.set_state(state_af) end 
	   	  bgfx.set_texture(0,self.render_ctx.u_base_uniform,self.textures[i].handle)
		  bgfx.set_texture(1,self.render_ctx.u_mask_uniform,self.masks[i].handle)       -- 不带mimap 的dds,默认最好时REPEAT,而不是CLAMP
		  bgfx.set_uniform(self.render_ctx.u_lightIntensity_uniform,{1.8,0,0,0})
		  bgfx.set_uniform(self.render_ctx.u_lightColor_uniform,{1,1,1,0.625})
	   	  bgfx.set_vertex_buffer( self.render_ctx.vbh )
	      bgfx.set_index_buffer( self.render_ctx.ibh )     								-- 使用 index 不正常显示？ wrong update api usage
	   	  bgfx.submit(0,self.render_ctx.prog)
		end 
	   --bgfx.submit(0, ctx.prog)
	  --]] 
end 

function Terrain:getheight(x,y)
    -- todo:
	local height = 0;
	return height;
end 

function Terrain:raycast( x,y,z )
	-- todo:
	return { hit,pos,obj }
end 

function Terrain:settexture( layer,tex)

end 

function Terrain:setmask( layer,tex)

end 

function Terrain:getmask()
	
end 


return Terrain



----- 使用方法 -----
--[[

--- 加载地形
local terrain = Terrain.new()  					            -- 可以这里传入 transform 
terrain.position = {20,10,10}
print("---load terrain---")
terrain:load("clibs/terrain/pvp.lvl")                       -- 注意对应的路径 
terrain:render(args)


function print_class(...)
	for k,v in pairs(...) do 
    	print('-'..k)
		print(v)
	end 
end 

print_class(terrain)


--- 创建新地形
local terrain1 = Terrain.new{ grid_width= 513; height=600; numlayers = 0; }    -- 初始化几何信息
terrain1:create()
terrain1:render(args)

print_class(terrain1)

-- destroy 
terrain = nil
terrain1 = nil 
]]





