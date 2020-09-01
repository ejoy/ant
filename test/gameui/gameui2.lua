local ecs = ...
local world = ecs.world

local renderpkg	= import_package "ant.render"
local assetmgr	= import_package "ant.asset"
local bgfx 		= require "bgfx"
local bgfxfont 	= require "bgfx.font"
local platform 	= require "platform"
local Font 		= platform.font

local m = ecs.system 'gameui'

local irq = world:interface "ant.render|irenderqueue"

local text_tb = bgfx.transient_buffer "wwwwd"
local text_decl = bgfx.vertex_decl {
	{"POSITION", 2, true, false, "INT16",},
	{"TEXCOORD0",2, true, false, "INT16",},
	{"COLOR0",4, true, false, "UINT8",},
}
local rect_tb = bgfx.transient_buffer "wwd"
local rect_decl = bgfx.vertex_decl {
	{"POSITION", 2, true, false, "INT16",},
	{"COLOR0",4, true, false, "UINT8",},
}

local function create_ib(numquad)
    local ib = {}
    for i=1, numquad do
        local offset = (i-1) * 4
        ib[#ib+1] = offset + 0
        ib[#ib+1] = offset + 1
        ib[#ib+1] = offset + 2

        ib[#ib+1] = offset + 1
        ib[#ib+1] = offset + 3
        ib[#ib+1] = offset + 2
    end
    return bgfx.create_index_buffer(bgfx.memory_buffer('w', ib), "")
end

local ctx = {
	viewid = renderpkg.viewidmgr.generate "gameui",
	fontid = bgfxfont.addfont(Font "黑体"),
	fonttex = bgfx.create_texture2d(bgfxfont.fonttexture_size, bgfxfont.fonttexture_size, false, 1, "A8"),
	ascent = bgfxfont.fontheight(32, 0),
	ibhandle = create_ib(),
	fx = assetmgr.load_fx {
		vs = "/pkg/ant.test.gameui/fx/vs_uiquat.sc",
		fs = "/pkg/ant.test.gameui/fx/fs_uiquat.sc",
	},
	fontfx = assetmgr.load_fx {
		vs = "/pkg/ant.test.gameui/fx/vs_uifont.sc",
		fs = "/pkg/ant.test.gameui/fx/fs_uifont.sc"
	},
}
ctx.fontuniform = ctx.fontfx.uniforms[1].handle	-- s_texFont

function m:init()
	local queue = world:singleton_entity "main_queue"
	irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0xa0a0a0ff)
	bgfx.set_view_rect(ctx.viewid, 0,0, 1024, 768)

	renderpkg.fbmgr.bind(ctx.viewid, queue.render_target.fb_idx)
	
	bgfx.set_view_clear(ctx.viewid, "C", 0)
end

local state = bgfx.make_state ""
local FIX_POINT<const> = 8
local function fill_rect(x, y, w, h, color)
	local x0, y0 = x * FIX_POINT, y * FIX_POINT
	local x1, y1 = (x+w) * FIX_POINT, (y+h) * FIX_POINT

	rect_tb:packV(0, x0, y0, color)
	rect_tb:packV(1, x1, y0, color)
	rect_tb:packV(2, x0, y1, color)
	rect_tb:packV(3, x1, y1, color)
end

local function draw_quad(quadnum, tb)
	bgfx.set_index_buffer(ctx.ibhandle, 0, quadnum * 2 * 3)
	tb:setV(0, 0, quadnum * 4)
	bgfx.set_state(state)

	bgfx.submit(ctx.viewid, ctx.fx.prog, 0)
end

local function draw_rect(x, y, w, h, color)
	rect_tb:alloc(4, rect_decl)
	fill_rect(x, y, w, h, color)
	draw_quad(1, rect_tb)
end

local function draw_frame(x, y, w, h, color, line_width)
	rect_tb:alloc(4*4, rect_decl)
	fill_rect(x, 				y, 				x+w, 			y+line_width,	color);
	fill_rect(x, 				y+h-line_width, x+w,			y+h,			color);
	fill_rect(x,				y+line_width,	x+line_width,	y+h-line_width, color);
	fill_rect(x+w-line_width, 	y+line_width, 	x+w, 			y+h-line_width, color);

	draw_quad(4, rect_tb)
end

local function fill_text(x, y, g, g_def, color)
	local x0 = x + g.offset_x * FIX_POINT
	local y0 = y + g.offset_y * FIX_POINT

	local x1 = x0 + g.w * FIX_POINT
	local y1 = y0 + g.h * FIX_POINT

	local scale<const> = (0x8000 / bgfxfont.fonttexture_size)
	local u0 = g_def.u * scale
	local v0 = g_def.v * scale

	local u1 = (g_def.u + g_def.w) * scale
	local v1 = (g_def.v + g_def.h) * scale

	text_tb:packV(0, x0, y0, u0, v0, color)
	text_tb:packV(1, x1, y0, u1, v0, color)

	text_tb:packV(2, x0, y1, u0, v1, color)
	text_tb:packV(3, x1, y1, u1, v1, color)
end

local function draw_text(text, color, size)
	bgfx.set_texture(0, ctx.fontuniform, ctx.fonttex)
	local codepoints = bgfxfont.text_codepoints(text)

	local numchar = #codepoints
	text_tb:alloc(numchar*4, text_decl)
	local x, y=0, 0
	for ii=1, numchar do
		local cp = codepoints[ii]
		bgfxfont.update_char_texture(ctx.fonttex, cp, ctx.fontid)
		local g = bgfxfont.font_glyph(cp, "", ctx.fontid, size)
		local g_noresize = bgfxfont.font_glyph(cp, "", ctx.fontid)

		fill_text(x, y, g, g_noresize, color)
		x = x + g.advance_x
	end
	draw_quad(numchar, text_tb)
end

function m:ui_update()
	draw_rect(10,10, 200, 100, 0xff0000)
	draw_frame(300, 300, 50, 80, 0xff00, 2)

	draw_text("你好啊", 0x00ffff, 32)

	bgfxfont.submit()
end