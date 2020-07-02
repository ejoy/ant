local ecs = ...
local world = ecs.world
local camera = world:interface "ant.camera|camera"
local m = ecs.system 'gameui'
local renderpkg = import_package "ant.render"
local assetmgr = import_package "ant.asset"
local bgfx = require "bgfx"
local ui = require "bgfx.ui"

local ctx = {
	viewid = renderpkg.viewidmgr.generate "gameui",
	bind = false,
	prog = false,
}

function m:init()
	local queue = world:singleton_entity "main_queue"
	queue.render_target.viewport.clear_state.color = 0xa0a0a0ff
	bgfx.set_view_rect(ctx.viewid, 0,0, 1024, 768)
	ctx.bind = function()
		renderpkg.fbmgr.bind(ctx.viewid, queue.render_target.fb_idx)
	end

	ctx.fx = assetmgr.load_fx_file "/pkg/ant.test.gameui/uiquat.fx"
end

function m:ui_update()
	ctx.bind()

	ui.submit_rect(10,10, 200, 100, 0xff0000)
	ui.submit_frame(300, 300, 50, 80, 0xff00, 2)
	ui.submit()

	bgfx.submit(ctx.viewid, ctx.fx.prog)
end