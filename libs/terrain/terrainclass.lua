local lterrain = require 'lterrain'
local uclass = require 'terrain.utilclass'
local texLoad = require "terrain.utiltexture"
local bgfx = require "bgfx"


local shaderMgr = require "render.resources.shader_mgr"
local math3d = require "math3d"

local math3d_stack = math3d.new()

-- 文件读写需要统一到框架
local readfile = function( fname )
	local f = assert(io.open( fname,'rb'))
	local d = f:read('*a')
	f:close()
	return d 
end 

------ 定义 Terrain 类 -----
local TerrainClass = Class("antTerrain")

-- Class Owner Attributes ,Forward description for reader 
-- Terrain.render_ctx = {}                  -- render relative
-- Terrain.render_ctx.vbh = 0
-- Terrain.render_ctx.ibh = 0
-- Terrain.render_ctx.prog = 0
-- Terrain.render_ctx.uniforms = {} 
-- Terrain.render_ctx.uniform_values = {} 
-- Terrain.render_ctx.tex_chanel = {}
-- Terrain.rst                              -- rst readable
-- Terrain.transform = {}   				-- terrain's transform  pos/rot/scl
-- Terrain.bbox = {}        				-- terrain's bounding box 
-- Terrain.level = {} 						-- level info 

function TerrainClass:set_transform( args )
	local args = args or {
		t = {0,0,0,1},
		r = {0,0,0,0},
		s = {1,1,1,1}
	}
	self.rst = args 
	self.transform = math3d_stack( args.t,args.r,"dLm" )
end

-- name = "alias_name_uniform",s_name = "bgfx name", type = "il" or "v4" etc 
-- use program manually utils 
function TerrainClass:create_uniform( name, s_name, type, texchannel)
	self.render_ctx.uniforms[name] = bgfx.create_uniform(s_name,type)
	if texchannel ~= nil then 
		self.render_ctx.tex_chanel[name] = texchannel 
	end 
end 

function TerrainClass:set_uniform(name,value)
	self.render_ctx.uniform_values[name] = value 
end 

function TerrainClass:load_program( vs,fs )
	local uniforms = {}
	self.render_ctx.prog = shaderMgr.programLoad(vs,fs,uniforms)
end 

function TerrainClass:set_program( prog, uniforms )
	self.render_ctx.prog = prog
end 


-- 如果地形管卡配置文件的内容出现错误，如何防止挂起？
local function ext_load_terrain_material( mtlname )
	local data    = readfile( mtlname )
	local mtldata = "local mtl ="..data.." return mtl" 
	return load( mtldata ) ()								
end 

function TerrainClass:load_material( mtlname )
	-- load program from mtl 
	-- load textures from mtl
	-- laod uniforms from mtl
	self.mtl = ext_load_terrain_material( mtlname)

	-- check prog & uniforms 
	local uniforms = {}
	self.render_ctx.prog = shaderMgr.programLoad(assert(self.mtl.vs), assert(self.mtl.fs), uniforms)
	assert(self.render_ctx.prog ~= nil)

	-- check uniforms 
	for _,u in ipairs(self.mtl.uniforms) do 
		local name,s_name,type,texchannel 
		for k,v in pairs(u) do 
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
function  TerrainClass:create_vdecl( args )
    local args = args  or  {
				{"POSITION",3,"FLOAT"},   -- default attrib
				{"NORMAL",3,"FLOAT"},     -- or UINT8
				{"TEXCOORD0",2,"FLOAT"},  
				{"TEXCOORD1",2,"FLOAT"},
			  	--{"TANGENT",3,"FLOAT"},  -- or  UINT8
	}
	self.render_ctx.vdecl = bgfx.vertex_decl( args )
end 

-- level = level setting info 
-- data  = geometry 
-- args  = terrain level info 
function TerrainClass:init(args)      
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
	-- 
	self.rst = nil
	self.transform = nil  					-- rst terrain's pos/rot/scl
	self.bbox = nil        					-- terrain's bounding box 
		
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
	self.heightmap = nil

    -- default transform 
	self:set_transform()
end 

-- return terrain data context
local function ext_load_terrain_level( filename, vd )
	local  data = readfile(filename)
	local  lvldata = "local level ="..data.." return level" 
	return load( lvldata )()                		     
end

local function load_heightmap( filename )
	return readfile ( filename )
end 

function TerrainClass:load( filename,vd )
	self.level = ext_load_terrain_level( filename,vd )
	self:create( self.level, vd )
end 

function TerrainClass:load_heightmap( raw )
	self.heightmap = load_heightmap( raw )
	return self.heightmap 
end 
function TerrainClass:get_data_type()
	if self.level.bits == 8 then 
		return 'uchar'
	elseif self.level.bits == 16 then 
		return 'short'
	elseif self.level.bits == 32 then
		return 'float'
	end 
end 
-- level geometry info
function TerrainClass:get_heightmap()
	return self.heightmap
end 

function TerrainClass:get_grid_width()
	return self.level.grid_width 
end 
function TerrainClass:get_grid_length()
	return self.level.grid_length 
end 

function TerrainClass:get_height_scale()
	return lterrain.get_height_scale( self.data )
end 
function TerrainClass:get_width_scale()
	return lterrain.get_width_scale( self.data )
end
function TerrainClass:get_length_scale()
	return lterrain.get_length_scale( self.data)
end 
------------
function TerrainClass:get_min_height()
	return lterrain.get_min_height( self.data )
end 
function TerrainClass:get_max_height()
	return lterrain.get_max_height( self.data ) 
end 
function TerrainClass:get_raw_height(x,y)
	return lterrain.get_raw_height( self.data, x, y)
end 
------------
function TerrainClass:get_phys_x_offset()
	local scale = lterrain.get_width_scale( self.data )
	local grid  = self:get_grid_width()
	return scale*(grid-1)*0.5
end 
function TerrainClass:get_phys_z_offset()
	local scale = lterrain.get_length_scale( self.data )
	local grid  = self:get_grid_length()
	return scale*(grid-1)*0.5
end 
function TerrainClass:get_phys_h_offset()
	local min_height = lterrain.get_min_height( self.data )
	local max_height = lterrain.get_max_height( self.data )
	return 0.5*(max_height+min_height)
end 

function TerrainClass:get_phys_offset()
	local ofs = {
		self:get_phys_x_offset(),
		self:get_phys_h_offset(),
		self:get_phys_z_offset(),
	}
	return ofs
end 

----------------
function TerrainClass:get_terrain_info()
	local info = {}
	info.grid_width  = self.level.grid_width 
	info.grid_length = self.level.grid_length 
	info.grid_scale   = lterrain.get_width_scale( self.data)
	info.height_scale = lterrain.get_height_scale( self.data )
	info.min_height = lterrain.get_min_height( self.data )
	info.max_height = lterrain.get_max_height( self.data )
	return info 
end 

function TerrainClass:get_height( x,z) 
	return  lterrain.get_height( self.data,x,z)
end 

-- create terrain data 
function TerrainClass:create( args, vd )

    local args = args or self.level   

	if args.raw then 
		self.heightmap = self:load_heightmap( args.raw )
	end 

    if  args.numlayers then 
		self.numlayers = args.numlayers 
	end 
	for i=1,args.numlayers,1  do
		self.textures[i] = texLoad( args.textures[i] )
		self.masks[i] = texLoad( args.masks[i] )
	end 

	self:create_vdecl( vd )
	self.data  = lterrain.create(self.heightmap,args,self.render_ctx.vdecl)
	self.vbo   = self.data:allocVB()
	self.ibo   = self.data:allocIB()

	lterrain.update_mesh( self.data,self.vbo,self.ibo) 

	local num = self.data:getNumVerts()
	self.render_ctx.vbh = bgfx.create_dynamic_vertex_buffer( num, self.render_ctx.vdecl );
	bgfx.update( self.render_ctx.vbh, 0, {'!',self.vbo} )

	num = self.data:getNumIndices()
	self.render_ctx.ibh = bgfx.create_dynamic_index_buffer( num,"rwd" )
	bgfx.update( self.render_ctx.ibh, 0, {self.ibo} )
end 

function TerrainClass:update( eye,dir)
	self.eye = eye 
	self.dir = dir 
	-- future todo: maybe lod etc 
	-- lterrain.update( self.data,self.vb,self.ib,eye,dir)
end 


-- move to terrain_sys will be good 
function TerrainClass:render( viewId, w,h,prim_type, ufn, world )
	-- local srt = { t= self.eye or {0,130,-10,1},
	--               r= self.dir or {25,45,0,0},
	-- 			  	 s= {1,1,1,1} }          								     -- for terrain ,eye,target
	-- 																	     	 -- yaw = 45,	pitch = 25
	-- local proj_mtx = math3d_stack( { type = "proj",n=0.1, f = 1000, fov = 60, aspect = w/h } , "m")  
	-- local view_mtx = math3d_stack( srt.t,srt.r,"dLm" )    			     	 -- math3d_statck( op data 1,2,..,"op code string")

	-- bgfx.set_view_clear( viewId, "CD", 0x303030ff, 1, 0)
	-- bgfx.set_view_rect( viewId, 0, 0, w, h)
	-- bgfx.reset(w,h, "vmx")
	-- bgfx.touch(viewId)
	-- bgfx.set_view_transform(viewId,view_mtx,proj_mtx)

	local prim_type = prim_type or  nil -- "LINES" --
	local state =  bgfx.make_state( { CULL="CW", PT = prim_type ,
									 WRITE_MASK = "RGBAZ",
									 DEPTH_TEST	= "LEQUAL"
								    } , nil)        									-- for terrain
	bgfx.set_state( state )
	local state_af =  bgfx.make_state( { CULL="CW", PT = prim_type ,
										 WRITE_MASK = "RGBA",
										 BLEND = "ALPHA",
										 DEPTH_TEST	= "LEQUAL"
										} , nil)        								-- for terrain

	-- don't do like this 
	-- local uniforms = nil
	-- for _,l_eid in world:each("shadow_maker") do 
	-- 	local  sm_ent   = world[l_eid]
	-- 	uniforms = sm_ent.shadow_rt.uniforms 
	-- end 	

	for i=1,self.numlayers do 
	--for i=1,1 do 
	   bgfx.set_transform(self.transform)
	   if i > 1 then bgfx.set_state(state_af) end
	   -- textures	 
	   for k,u in pairs(self.render_ctx.uniforms) do 
		   local tex_chanel = -1
		   if self.render_ctx.tex_chanel[k] ~=nil and self.render_ctx.tex_chanel[k] >=0   then    -- texture channel
				tex_chanel = self.render_ctx.tex_chanel[k]
				if tex_chanel == 0 then 
					bgfx.set_texture( tex_chanel,self.render_ctx.uniforms[k], self.textures[i].handle)	 
				elseif tex_chanel == 1 then 
					bgfx.set_texture( tex_chanel,self.render_ctx.uniforms[k], self.masks[i].handle)
				else 
					-- local switch = {
					-- 	[4] = function()
					-- 		return uniforms.s_shadowMap0
					-- 		end,
					-- 	[5] = function() 
					-- 		return uniforms.s_shadowMap1
					-- 		end,
					-- 	[6] = function()
					-- 		return uniforms.s_shadowMap2
					-- 		end,
					-- 	[7] = function()
					-- 		return uniforms.s_shadowMap3
					-- 		end,
					-- }
					-- local f = switch[tex_chanel]
					-- if f then 
					--   print("set unifroms ",k,self.render_ctx.uniforms[k],f() )
					--   bgfx.set_texture( tex_chanel, self.render_ctx.uniforms[k], f() )	 		
					-- end 
				end 
		   else 
				bgfx.set_uniform(self.render_ctx.uniforms[k],self.render_ctx.uniform_values[k] )  -- normal uniforms 
		   end 	
	   end 

	   ufn()

 	   bgfx.set_vertex_buffer( self.render_ctx.vbh )
	   bgfx.set_index_buffer( self.render_ctx.ibh )     							 			  -- 使用 index 不正常显示？ wrong update api usage
	   bgfx.submit( viewId, self.render_ctx.prog)
	end 

	local state =  bgfx.make_state( { CULL="CW", PT = prim_type ,
									 WRITE_MASK = "RGBAZ",
									 DEPTH_TEST	= "LEQUAL"
								    } , nil)        									-- for terrain
	bgfx.set_state( state )

end


-- local ctx = {} 
-- local CUBE_TEST = 0
-- function TerrainClass:render_test( w,h  )

-- 	lterrain.render( self.data )

-- 	local frustum = {} 
-- 	mathu.frustum_from_fov(frustum, 0.1, 1000, 60, w / h)
-- 	local proj_mat = mathu.proj_v(math3d_stack, frustum)

-- 	local view_mat = math3d.ref "matrix"  
-- 	view_mat(t,{0,20,-10,1},"=")
-- 	view_mat(r,{0,45,0,0},"=")
-- 	view_mat(s,{1,1,1,1},"=")

-- 	-- 必须在函数前，写明参数，个数，字符串表示参数意义，用法，否则，需要太多时间查询过多的关联函数和文件
-- 	-- math_stack(op data1,op data2,..."op code string")
-- 	local srt = { t= {0,130,-10,1},r={25,45,0,0},s= {1,1,1,1} }     -- for terrain ,eye,target
-- 																	-- yaw = 45,	pitch = 25
-- 	local proj_mtx = math3d_stack( { type = "proj",n=0.1, f = 1000, fov = 60, aspect = w/h } , "m")  
-- 	local view_mtx = math3d_stack( srt.t,srt.r,"dLm" )   	   		-- math3d_statck( op data 1,2,..,"op code string")
-- 															   		-- view_system.lua 
-- 															   		-- L generate lookat,d convert rot to dir
-- 															   		-- m pop matrix pointer 
-- 															   		-- for cube 

-- 	-- test2
--     local mtx = math3d_stack( {0,20,-10,1},{0,45,0,0},"lP")      -- lookat matrix 
-- 	local mat = math3d.ref "matrix"	
-- 	math3d_stack(mat,"1=")
-- 	mat(mtx)

-- 	local srt1 = { s={2,2,2},r={0,40,0,0},t={100,60,100,1} }
-- 	local obj_mtx = math3d_stack( srt1.t,srt1.r,"dLm" )

-- 	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
-- 	bgfx.touch(0)

-- 	bgfx.dbg_text_clear()
-- 	bgfx.dbg_text_print(0, 1, 0xf, "lua \x1b[9;mt\x1b[10;me\x1b[11;mr\x1b[12;mr\x1b[13;ma\x1b[14;mi\x1b[0mn API test.");

-- 	if CUBE_TEST == 0 then 
-- 		ctx.width  = w
-- 		ctx.height = h
-- 		ctx.prog   = shaderMgr.programLoad("vs_cubes", "fs_cubes")

-- 		ctx.state = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- from BGFX_STATE_DEFAULT
-- 		ctx.vdecl = bgfx.vertex_decl {
-- 			{ "POSITION", 3, "FLOAT" },
-- 			{ "COLOR0", 4, "UINT8", true },
-- 		}
-- 		ctx.vb = bgfx.create_vertex_buffer({
-- 				"fffd",
-- 				-1.0,  1.0,  1.0, 0xff000000,
-- 				1.0,  1.0,  1.0, 0xff0000ff,
-- 				-1.0, -1.0,  1.0, 0xff00ff00,
-- 				1.0, -1.0,  1.0, 0xff00ffff,
-- 				-1.0,  1.0, -1.0, 0xffff0000,
-- 				1.0,  1.0, -1.0, 0xffff00ff,
-- 				-1.0, -1.0, -1.0, 0xffffff00,
-- 				1.0, -1.0, -1.0, 0xffffffff,
-- 			},
-- 			ctx.vdecl)
-- 		ctx.ib = bgfx.create_index_buffer{
-- 			0, 1, 2, 3, 7, 1, 5, 0, 4, 2, 6, 7, 4, 5,
-- 		}

-- 		print("cube vb = "..ctx.vb)
-- 		print("cube ib = "..ctx.ib)
-- 		CUBE_TEST = 1
-- 	end 

-- 	bgfx.set_view_rect(0, 0, 0, w, h)
-- 	bgfx.reset(w,h, "vmx")
-- 	bgfx.set_view_transform(0,view_mtx,proj_mtx)

-- 	if CUBE_TEST == 1 then 
-- 		local state = bgfx.make_state { CULL = "CW",PT = "TRISTRIP", }
-- 		bgfx.set_state(state)
-- 		bgfx.set_vertex_buffer(ctx.vb)
-- 		bgfx.set_index_buffer(ctx.ib)
-- 		bgfx.submit(0, ctx.prog)
-- 	end 

-- 	---[[ terrain 
-- 	local prim_type = "LINES" -- nil -- 
-- 	local state =  bgfx.make_state({ CULL="CW", PT = prim_type ,
-- 									WRITE_MASK = "RGBAZ",
-- 									DEPTH_TEST	= "LEQUAL"
-- 									} , nil)        									-- for terrain
-- 					--bgfx.make_state ( { CULL = "CW",PT = "TRISTRIP"},nil )      	-- for cube 
-- 	bgfx.set_state(state)

-- 	local state_af =  bgfx.make_state({ CULL="CW", PT = prim_type ,
-- 										WRITE_MASK = "RGBA",
-- 										BLEND = "ALPHA",
-- 										DEPTH_TEST	= "LEQUAL"
-- 									} , nil)        								-- for terrain

-- 	--bgfx.set_transform( obj_mtx )
-- 	for i=1,self.numlayers do 
-- 		if i > 1 then bgfx.set_state(state_af) end 
-- 		bgfx.set_texture(0,self.render_ctx.u_base_uniform,self.textures[i].handle)
-- 		bgfx.set_texture(1,self.render_ctx.u_mask_uniform,self.masks[i].handle)       -- 不带mimap 的dds,默认最好时REPEAT,而不是CLAMP
-- 		bgfx.set_uniform(self.render_ctx.u_lightIntensity_uniform,{1.8,0,0,0})
-- 		bgfx.set_uniform(self.render_ctx.u_lightColor_uniform,{1,1,1,0.625})
-- 		bgfx.set_vertex_buffer( self.render_ctx.vbh )
-- 		bgfx.set_index_buffer( self.render_ctx.ibh )     								-- 使用 index 不正常显示？ wrong update api usage
-- 		bgfx.submit(0,self.render_ctx.prog)
-- 	end 
-- 	  --bgfx.submit(0, ctx.prog)
-- 	  ---]] 
-- end 

function TerrainClass:raycast( x,y,z )
	-- todo:
	return { hit,pos,obj }
end 

function TerrainClass:set_texture( layer,tex)

end 

function TerrainClass:set_mask( layer,tex)

end 

function TerrainClass:get_mask( layer )
	
end 

return TerrainClass

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
