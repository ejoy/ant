-- luacheck: globals log
local log = log and log(...) or print

local bgfx = require "bgfx"
local viewidmgr = require "viewid_mgr"
local fs = require "filesystem"

local util = {}
util.__index = util

local property_types = {
    color = "v4",
    v4 = "v4",
    m4 = "m4",
    texture = "s",
}

local function update_properties(shader, properties, render_properties)
	local su = shader.uniforms	
	for name, u in pairs(su) do
		local function find_property(name, properties)
			local uniforms = properties.uniforms
			if uniforms then
				local p = uniforms[name]
				if p then
					return p
				end
			end
			local textures = properties.textures
			return textures and textures[name] or nil
		end

		local p = find_property(name, properties)
		p = p or find_property(name, render_properties.lighting)
		p = p or find_property(name, render_properties.shadow)

		if p then
			assert(property_types[p.type] == u.type)
			if p.type == "texture" then
				bgfx.set_texture(assert(p.stage), u.handle, p.handle)
			else				
				bgfx.set_uniform(u.handle, p.value)
			end
		else
			--log(string.format("uniform : %s, not privided, but shader program needed", name))
		end
	end
end

function util.draw_primitive(vid, primgroup, mat, render_properties)
    bgfx.set_transform(mat)

	-- local material = primgroup.material[3]  or primgroup.material
	-- local properties = primgroup.properties[3] or primgroup.properties
    -- bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
    -- update_properties(material.shader, properties, render_properties)

	-- 保留兼容，最好按实验结果重构
	local material = primgroup.material[i]  or primgroup.material
	local prog = material.shader.prog
	
	local mg = assert(primgroup.mgroup)
	local ib, vb = mg.ib, mg.vb

	local prims = mg.primitives
	if prims == nil or next(prims) == nil then
		if ib then
			bgfx.set_index_buffer(ib.handle)
		end
		for idx, v in ipairs(vb.handles) do
			bgfx.set_vertex_buffer(idx - 1, v)
		end
		
		bgfx.submit(vid, prog, 0, false)
	else
		local numprim = #prims

		for idx, v in ipairs(vb.handles) do
			bgfx.set_vertex_buffer(idx - 1, v)
		end
		for i=1, numprim do
			-- 这部分后续需要优化，提供机制判断一个mesh 是否具备多个材质，分开处理
			local material = primgroup.material[i]  or primgroup.material
		    local properties = primgroup.properties[i] or primgroup.properties
			bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
			update_properties(material.shader, properties, render_properties)

			local prog = material.shader.prog

			local prim = prims[i]
			if ib and prim.start_index and prim.num_indices then
				bgfx.set_index_buffer(ib.handle, prim.start_index, prim.num_indices)
			end
			bgfx.submit(vid, prog, 0, i~=numprim)
		end

		-- for i=1, numprim do
		-- 	local prim = prims[i]

		-- 	if ib and prim.start_index and prim.num_indices then
		-- 		bgfx.set_index_buffer(ib.handle, prim.start_index, prim.num_indices)
		-- 	end
		-- 	for idx, v in ipairs(vb.handles) do
		-- 		bgfx.set_vertex_buffer(idx - 1, v, prim.start_vertex, prim.num_vertices)
		-- 		--bgfx.set_vertex_buffer(idx - 1, v)
		-- 	end

		-- 	bgfx.submit(vid, prog, 0, i~=numprim)
		-- end

	end
end

local function add_result(eid, group, materialinfo, properties, worldmat, result)
	local idx = result.cacheidx
	local r = result[idx]
	if r == nil then
		r = {}
		result[idx] = r
	end

	r.eid 		= eid
	r.mgroup 	= group

	r.material 	= materialinfo
	r.properties = properties
	r.worldmat 	= worldmat

	result.cacheidx = idx + 1
end


function util.insert_primitive(eid, meshhandle, materials, worldmat, filter,group_id)	
	local mgroups = meshhandle.groups
	local results = filter.result	

	if group_id ~= nil then 
		local g = mgroups[ group_id ]
		local mc = materials[ group_id ] or materials[1] 

		-- this two variable trans to table parameters
		local mat_info = mc.materialinfo  				-- maybe need materials[] for primitives[],futhur extend
		local mat_properties = mc.properties 

		-- 一个primitive 带 n 个materials ，需要把这些materials 传到render 
		-- 这部分需要重写，合并到加载时候，不需要每次动态装配
		-- 存在这使用一个子材质，两个拷贝的现象，这个流程数据结构相关，也需要优化
		-- tested 
		local num_primitives = #g.primitives 
		if num_primitives > 1 and mat_info.ajust ~= 1 then 
			local base = g.primitives[1].material_idx
			-- for i=1,num_primitives do 
			-- 	local idx = g.primitives[i].material_idx
			-- 	if base > idx then 
			-- 		base = idx 
			-- 	end 
			-- end  
			--local base = g.primitives[1].material_idx
			for i=1,num_primitives do 
				local m_idx = g.primitives[i].material_idx
				m_idx = m_idx - base + 1
				local m_content = materials[m_idx] or materials[1]   -- some prim 
				table.insert(mat_info,m_content.materialinfo)
				--table.insert(mat_properties,m_content.properties)
			end 
			mat_info.ajust = 1
		end 

		if num_primitives > 1 and mat_properties.ajust ~= 1 then  
			local base = g.primitives[1].material_idx
			for i=1,num_primitives do 
				local m_idx = g.primitives[i].material_idx
				m_idx = m_idx - base + 1
				local m_content = materials[m_idx] or materials[1]   -- some prim 
				table.insert(mat_properties,m_content.properties)
			end 
			mat_properties.ajust = 1
		end 

		 

		if mat_info.surface_type.transparency == "translucent" then
			add_result(eid, g, mat_info, mat_properties, worldmat, results.translucent)
		else
			add_result(eid, g, mat_info, mat_properties, worldmat, results.opaque)
		end
	else
		--   compatible with the one mode
		for i=1, #mgroups do
			local g = mgroups[i]
			local mc = materials[i] or materials[1]


			local mi = mc.materialinfo
			
			if mi.surface_type.transparency == "translucent" then
				add_result(eid, g, mi, mc.properties, worldmat, results.translucent)
			else
				add_result(eid, g, mi, mc.properties, worldmat, results.opaque)
			end
		end
	end 
end

function util.create_render_queue_entity(world, viewsize, viewdir, eyepos, view_tag, viewid)
	local w, h = viewsize.w, viewsize.h
	return world:create_entity {
		camera = {
			type = "",
			eyepos = eyepos,
			viewdir = viewdir,
			updir = {0, 1, 0, 0},
			frustum = {
				type = "mat",
				n = 0.1, f = 1000,
				fov = 60, aspect = w / h,
			},
		},
		viewid = viewid or viewidmgr.get(view_tag),
		render_target = {
			viewport = {
				clear_state = {
					color = 0x303030ff,
					depth = 1,
					stencil = 0,
					clear = "all",
				},
				rect = {
					x = 0, y = 0,
					w = w, h = h,
				},
			},
		},
		primitive_filter = {
			view_tag = view_tag,
			filter_tag = "can_render",
		},
		main_queue = view_tag == "main_view" and true or nil,
		visible = true,
	}	
end

function util.default_sampler()
	return {
		U="MIRROR",
		V="MIRROR",
		W="MIRROR",
		MIN="LINEAR",
		MAG="LINEAR",
		MIP="LINEAR",
	}
end

function util.fill_default_sampler(sampler)
	local d = util.default_sampler()
	if sampler == nil then
		return d
	end

	for k, v in pairs(d) do
		if sampler[k] == nil then
			sampler[k] = v
		end
	end

	return sampler
end

local sample_types = {
	U="u", V="v", W="w", 
	MIN="-", MAG="+", MIP="*",

	COMPARE="c",
	BOARD_COLOR="c",

	RT = "r", 
	RT_READWRITE = "r", 
	RT_MSAA="r",

	BLIT = "b",
	BLIT_READBACK = "b", 
	BLIT_COMPUTE = "b",

	SAMPLE = "s",
}

local sample_value = {
	CLAMP="c", BORDER="b", MIRROR="",	--default
	POINT="p", ANISOTROPIC="a", LINEAR="", --default,

	-- compare
	COMPARE_LESS = '<',
	COMPARE_LEQUAL = '[',
	COMPARE_EQUAL = '=',
	COMPARE_GEQUAL = ']',
	COMPARE_GREATER = '>',
	COMPARE_NOTEQUAL = '!',
	COMPARE_NEVER = '-',
	COMPARE_ALWAYS = '+',

	-- RT
	RT_ON='t', 
	RT_READ="", RT_WRITE="w",
	RT_MSAA2="2", RT_MSAA4="4", RT_MSAA8="8", RT_MSAAX="x",

	-- BLIT
	BLIT_AS_DST = 'w', 
	BLIT_READBACK_ON = 'r',
	BLIT_COMPUTEREAD = '',
	BLIT_COMPUTEWRITE = 'c',	

	--SAMPLE
	SAMPLE_STENCIL='s', SAMPLE_DEPTH='d',
}

function util.generate_sampler_flag(sampler)
	if sampler == nil then
		return nil
	end
	local flag = ""

	for k, v in pairs(sampler) do
		if k == "BOARD_COLOR" then
			flag = flag .. sample_types[k] .. v
		else
			local value = sample_value[v]
			if value == nil then
				error("not support data, sample value : %s", v)
			end
	
			if #value ~= 0 then
				local type = sample_types[k]
				if type == nil then
					error("not support data, sample type : %s", k)
				end
				
				flag = flag .. type .. value
			end
		end
	end

	return flag
end

function util.default_surface_type()
	return {
		lighting = "on",			-- "on"/"off"
		transparency = "opaticy",	-- "opaticy"/"transparent"
		shadow	= {
			cast = "on",			-- "on"/"off"
			receive = "on",			-- "on"/"off"
		},
		subsurface = "off",			-- "on"/"off"? maybe has other setting
	}
end

-- function util.create_frame_buffer(world,hwnd,w,h,viewid)
-- 	local fb_handle = bgfx.create_frame_buffer(hwnd, w, h)
-- 	bgfx.set_view_frame_buffer(viewid, assert(fb_handle))
-- 	local frame_buffer = {
-- 		render_buffers = {},
-- 		viewid = viewid,
-- 	}
-- 	local frame_buffer_com = world:create_component("frame_buffer",frame_buffer)
-- 	frame_buffer_com.handle = fb_handle
-- 	fbmgr.bind(viewid,frame_buffer_com)
-- end

--frame_buffer:component
function util.create_general_render_queue(world,viewsize,view_tag,viewid)
	local default_viewdir = { -25, -45, 0, 0 }
	local default_eyepos = { 5, 5, -5, 1 }
	local entity_id = util.create_render_queue_entity(world,viewsize,
					default_viewdir,
					default_eyepos,
					view_tag,
					viewid)
	local frame_buffer = {ref_viewid = viewid}
	-- if not frame_buffer.ref_viewid then
	-- 	local default_render_buffer = {
	-- 			w = viewsize.w,
	-- 			h = viewsize.h,
	-- 			layers = 1,
	-- 			format = "RGBA32",
	-- 			flags = util.generate_sampler_flag {
	-- 				RT="RT_ON",
	-- 				MIN="POINT",
	-- 				MAG="POINT",
	-- 				U="CLAMP",
	-- 				V="CLAMP"
	-- 			}
	-- 		}
	-- 	frame_buffer.render_buffers = frame_buffer.render_buffers or {default_render_buffer}
	-- 	frame_buffer.manager_buffer = true
	-- end
	-- world[entity_id].frame_buffer = frame_buffer
	world:add_component(entity_id,"frame_buffer",frame_buffer)

	return entity_id
end

function util.identify_transform()
	return {
		s = {1, 1, 1, 0},
		r = {0, 0, 0, 0},
		t = {0, 0, 0, 1},
	}
end

return util