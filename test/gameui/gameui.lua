local ecs = ...
local world = ecs.world
local camera = world:interface "ant.camera|camera"
local m = ecs.system 'gameui'
local renderpkg = import_package "ant.render"
local assetmgr = import_package "ant.asset"
local bgfx = require "bgfx"

local ctx = {
	viewid = renderpkg.viewidmgr.generate "gameui",
	bind = false,
	tvb = false,
	ib = false,
	prog = false,
	vdecl = bgfx.vertex_layout {
		{ "POSITION", 2, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	},
	state = bgfx.make_state {
--		BLEND = "NORMAL",
		WRITE_MASK = "RGBA",
		MSAA = true,
		DEPTH_TEST = "LESS",
	}
}

function m:init()
	local queue = world:singleton_entity "main_queue"
	queue.render_target.viewport.clear_state.color = 0xa0a0a0ff
	bgfx.set_view_rect(ctx.viewid, 0,0, 1024, 768)
	bgfx.set_view_clear(ctx.viewid, "C", 0x808080FF)
	ctx.bind = function()
		renderpkg.fbmgr.bind(ctx.viewid, queue.render_target.fb_idx)
	end

	ctx.tvb = bgfx.transient_buffer "wwd"
	ctx.fx = assetmgr.load_fx_file "/pkg/ant.test.gameui/uiquat.fx"
	ctx.ib = bgfx.create_index_buffer {
		0, 1, 2, 1, 3, 2,
	}
	ctx.vb = bgfx.create_vertex_buffer(bgfx.memory_buffer("ffd", {
		100, 100, 0xff0000ff,
		200, 100, 0xff0000ff,
		100, 200, 0xff0000ff,
		200, 200, 0xff0000ff,
		}),	ctx.vdecl)
end

function m:ui_update()
	ctx.bind()

--[[
	local maxVertices = (32<<10)
	ctx.tvb:alloc(maxVertices, ctx.vdecl)
	ctx.tvb:packV(0, 100, 100, 0xff0000ff)
	ctx.tvb:packV(1, 200, 100, 0xff0000ff)
	ctx.tvb:packV(2, 100, 200, 0xff0000ff)
	ctx.tvb:packV(3, 200, 200, 0xff0000ff)
	ctx.tvb:setV(ctx.viewid, 0, 4)
]]
	bgfx.set_vertex_buffer(ctx.vb)
	bgfx.set_index_buffer(ctx.ib)
	bgfx.set_state(ctx.state)
	bgfx.submit(ctx.viewid, ctx.fx.prog)
end