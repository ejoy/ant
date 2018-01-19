-- system for simple.lua
local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"

local init_bgfx = ecs.system "init_bgfx"

function init_bgfx:init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	bgfx.set_debug "T"
end

local render_frame = ecs.system "render_frame"

function render_frame:update()
	bgfx.touch(0)
	bgfx.frame()
end

local window = ecs.component "window" {
	width = 0,
	height = 0,
}

local iup_message = ecs.system "iup_message"
iup_message.singleton "window"

local message = {}

function message:resize(w,h)
	print("RESIZE", w,h)
	self.window.width = w
	self.window.height = h
	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.reset(w,h, "v")
end

function message:button(...)
	print("BUTTON", ...)
end

function iup_message:update()
	for idx, msg, v1,v2,v3 in pairs(world.args.mq) do
		local f = message[msg]
		if f then
			f(self,v1,v2,v3)
		end
	end
end
