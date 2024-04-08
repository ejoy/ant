local ecs	= ...
local world = ecs.world
local w 	= world.w

local bgfx 			= require "bgfx"
local fbmgr			= require "framebuffer_mgr"
local layoutmgr		= require "vertexlayout_mgr"

local hwi			= import_package "ant.hwi"
local sampler		= import_package "ant.render.core".sampler
local setting		= import_package "ant.settings"
local ED 			= world:clibs "entity.drawer"

local ig			= ecs.require "ant.group|group"
local ivm			= ecs.require "visible_mask"
local queuemgr		= ecs.require "queue_mgr"
local INV_Z<const>	= setting:get "graphic/inv_z"

local irender		= {}

local STOP_DRAW = false
function irender.stop_draw(stop)
	if nil == stop then
		return STOP_DRAW
	end
	STOP_DRAW = stop
end

function irender.screen_capture(force_read)
	for e in w:select "main_queue render_target:in" do
		local fbidx = e.render_target.fb_idx
		--Force to enable HDR as RGBA16F
		local format<const> = "RGBA16F"
		local handle, width, height, pitch = irender.read_render_buffer_content(format, fbmgr.get(fbidx)[1].rbidx, force_read)
		return width, height, pitch, tostring(handle)
	end
end

function irender.is_msaa_buffer(rbidx)
	local rb = fbmgr.get_rb(rbidx)
	return rb.flags:match "r[248x]" ~= nil
end

function irender.read_render_buffer_content(format, rb_idx, force_read, size)
	local rb = fbmgr.get_rb(rb_idx)
	local w, h
	if size then
		w, h = size.w, size.h
	else
		w, h = rb.w, rb.h
	end

	local elem_size_mapper = {
		RGBA8 = 4,
		RGBA16F = 8,
	}

	local elem_size = assert(elem_size_mapper[format])

	local memory_handle = bgfx.memory_texture(w * h * elem_size)
	local rb_handle = fbmgr.get_rb(fbmgr.create_rb {
		w = w,
		h = h,
		layers = 1,
		format = format,
		flags = sampler {
			BLIT="BLIT_AS_DST|BLIT_READBACK_ON",
			MIN="POINT",
			MAG="POINT",
			U="CLAMP",
			V="CLAMP",
		}
	}).handle

	local viewid = hwi.viewid_get "blit"
	if viewid == nil then
		viewid = hwi.viewid_generate "blit"
	end
	bgfx.blit(viewid, rb_handle, 0, 0, rb.handle)
	bgfx.read_texture(rb_handle, memory_handle)

	if force_read then
		bgfx.frame()
		bgfx.frame()
	end

	return memory_handle, size.w, size.h, size.w * elem_size
end

function irender.set_visible_by_eid(eid, visible)
	local e <close> = world:entity(eid, "visible?out")
	e.visible = visible
end

function irender.set_visible(e, visible)
	w:extend(e, "visible?out")
	e.visible = visible
end

function irender.is_visible(e)
	w:extend(e, "visible?in")
	return e.visible
end

function irender.set_castshadow(e, cast)
	ivm.set_masks(e, "cast_shadow", cast)
end

function irender.is_castshadow(e)
	return ivm.check(e, "cast_shadow")
end

function irender.set_selectable(e, s)
	ivm.set_masks(e, "selectable", s)
end

function irender.is_selectable(e)
	return ivm.check(e, "selectable")
end

--[[
	1 ---- 3
	|      |
	|      |
	0 ---- 2
]]

local function create_quad_ib(num_quad)
    local b = {}
    for ii=1, num_quad do
        local offset = (ii-1) * 4
        b[#b+1] = offset + 0
        b[#b+1] = offset + 1
        b[#b+1] = offset + 2

        b[#b+1] = offset + 1
        b[#b+1] = offset + 3
        b[#b+1] = offset + 2
    end

    return bgfx.create_index_buffer(bgfx.memory_buffer("w", b))
end

local quad_ib_num<const> = 2048
local ibhandle<const> = create_quad_ib(quad_ib_num)
function irender.quad_ib()
	return ibhandle
end

function irender.quad_ib_num()
	return quad_ib_num
end

function irender.quad_ibobj(start, num)
	if nil == num then
		assert(start > 0, "Invalid quad num, should be > 0")
		start, num = 0, start
	end

	if start then
		assert(nil ~= num, "Need provided 'num' value")
	else
		error("Need provided ('start' and 'num') or 'num', like: quad_ibobj(10) mean start=0, num=10, or quad_ibobj(1, 10) mean start=1, num=10")
	end

	return {
		start = start,
		num = num,
		handle = ibhandle,
	}
end

local fullquad_vbhandle = bgfx.create_vertex_buffer(bgfx.memory_buffer("b", {1, 1, 1}), layoutmgr.get "p10NIu".handle)
local fullquad<const> = {
	vb = {
		start = 0, num = 3,
		handle=fullquad_vbhandle,
	}
}
function irender.full_quad()
	return fullquad
end

local VEC4_SIZE<const> = 16 --uvec4/vec4 = 16 bytes
function irender.align_buffer(s, alignsize)
	alignsize = alignsize or VEC4_SIZE
    local n = #s % alignsize
    if n > 0 then
        s = s .. ('\0'):rep(alignsize - n)
    end
    return s
end

local NO_DEPTH_TEST_STATES<const> = {
    NEVER = true, ALWAYS = true, NONE = true
}

function irender.has_depth_test(s)
	local ss = bgfx.parse_state(s)
	if ss.DEPTH_TEST and not NO_DEPTH_TEST_STATES[ss.DEPTH_TEST] then
        return ss
    end
end

function irender.create_depth_state(os)
    local s = irender.has_depth_test(os)
    if s and not s.BLEND then
        s.DEPTH_TEST = INV_Z and "GREATER" or "LESS"
		s.WRITE_MASK = "Z"
        return bgfx.make_state(s)
    end
end

function irender.create_write_state(os)
    local s = irender.has_depth_test(os)
    if s and not s.BLEND then
        s.DEPTH_TEST = INV_Z and "GREATER" or "LESS"
		s.WRITE_MASK = "RGBAZ"
        return bgfx.make_state(s)
    end
end

local function group_filter_flush(go)
	go:flush()
    go:filter("render_object_visible", "render_object")
    go:filter("hitch_visible", "hitch")
	--go:filter("efk_visible", "efk")
end

irender.group_flush = group_filter_flush

function irender.group_obj(tag)
	local go = ig.obj(tag)
	assert(not go.filter_flush)
	go.filter_flush = group_filter_flush
	return go
end

local RA_FMT<const> = "HBB"
function irender.pack_render_arg(name, viewid)
    local qidx = queuemgr.queue_index(name)
    local midx = queuemgr.material_index(name)
    return RA_FMT:pack(viewid, qidx, midx)
end

function irender.draw(ra, eid)
	ED.draw(ra, eid)
end

function irender.draw_with_tag(ra, tag)
	irender.draw(ra, w:first(tag .. " eid:in").eid)
end

return irender
