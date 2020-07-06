local ecs = ...
local world = ecs.world
local camera = world:interface "ant.camera|camera"
local m = ecs.system 'gameui'
local renderpkg = import_package "ant.render"
local assetmgr = import_package "ant.asset"
local bgfx = require "bgfx"
local ui = require "bgfx.ui"
local platform = require "platform"
local Font = platform.font

local ctx = {
	viewid = renderpkg.viewidmgr.generate "gameui",
	bind = false,
	prog = false,
	fonttex = false,
	fx = false,
	fontfx = false,
	fonttex = false,
}

function m:init()
	local queue = world:singleton_entity "main_queue"
	queue.render_target.viewport.clear_state.color = 0xa0a0a0ff
	bgfx.set_view_rect(ctx.viewid, 0,0, 1024, 768)
	ctx.bind = function()
		renderpkg.fbmgr.bind(ctx.viewid, queue.render_target.fb_idx)
	end

	ctx.fx = assetmgr.load_fx "/pkg/ant.test.gameui/uiquat.fx"
	ctx.fontfx = assetmgr.load_fx "/pkg/ant.test.gameui/uifont.fx"
	ctx.fontuniform = ctx.fontfx.uniforms[1].handle	-- s_texFont
	local fontid = ui.addfont(Font "黑体")
	assert(fontid == 0)
	local size = ui.fonttexture_size
	ctx.fonttex = bgfx.create_texture2d(size, size, false, 1, "A8")
	bgfx.set_view_clear(ctx.viewid, "C", 0)
end

function m:ui_update()
	ctx.bind()

	local x, y = assert(ui.prepare_text(ctx.fonttex, "好"))
	local codepoint = utf8.codepoint "好"

	ui.submit_rect(10,10, 200, 100, 0xff0000)
	ui.submit_frame(300, 300, 50, 80, 0xff00, 2)
	ui.submit()

	bgfx.submit(ctx.viewid, ctx.fx.prog)

	ui.submit_char(300,300, 24, 0x0000ff, codepoint)
	ui.submit()
	bgfx.set_texture(0, ctx.fontuniform, ctx.fonttex)
	bgfx.submit(ctx.viewid, ctx.fontfx.prog)


end