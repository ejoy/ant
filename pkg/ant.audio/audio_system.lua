local ecs = ...
local platform = require "bee.platform"
local fs = require "filesystem"
--local assetmgr = import_package "ant.asset"
local audio_sys = ecs.system "audio_system"
local ia = ecs.interface "audio_interface"
local caudio
local play_sound = function() end
if "android" ~= platform.os then
    caudio = require "audio"
	play_sound = caudio.play
end

local sys_obj = setmetatable({}, {
	__index = function()
		return function() end
	end })

local event_list = {}

function ia.load_bank(filename)
	local localf = fs.path(filename):localpath():string()
	sys_obj:load_bank(localf, event_list)
end

function ia.play(event_name)
	play_sound(event_list[event_name])
end

function audio_sys:init()
    if not caudio then return end
	sys_obj = caudio.init()
end

function audio_sys:data_changed()
	sys_obj:update()
end

function audio_sys:exit()
	sys_obj:shutdown()
end