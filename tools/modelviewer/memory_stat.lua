local ecs = ...

local math3d = require "math3d"
local imgui = require "imgui.ant"
local rp3d = require "rp3d.core"
local imgui_util = require "imgui_util"

local m = ecs.system "memory_stat"

m.require_system "ant.imguibase|imgui_system"

local function memory_info()
	local function bytestr(n)
		if n < 1024 then
			return ("%dB"):format(n)
		end
		n = n / 1024.0
		if n < 1024 then
			return ("%.1fKB"):format(n)
		end
		n = n / 1024.0
		return ("%.1fMB"):format(n)
	end
	local s = {}
	local platform = require "platform"
	local bgfx = require "bgfx"
	s[#s+1] = ""
	s[#s+1] = ("sys   memory:%s"):format(bytestr(platform.info "memory"))
	s[#s+1] = ("lua   memory:%s"):format(bytestr(collectgarbage "count" * 1024.0))
	s[#s+1] = ("bgfx  memory:%s"):format(bytestr(bgfx.get_memory()))
	s[#s+1] = ("math  memory:%s"):format(bytestr(math3d.stacksize()))
	s[#s+1] = ("imgui memory:%s"):format(bytestr(imgui.ant.memory()))
	s[#s+1] = ("rp3d  memory:%s"):format(bytestr(rp3d.memory()))
	s[#s+1] = "-------------------"
	local data = bgfx.get_stats "m"
	s[#s+1] = ("rt   memory:%s"):format(bytestr(data.rtMemoryUsed))
	s[#s+1] = ("tex  memory:%s"):format(bytestr(data.textureMemoryUsed))
	s[#s+1] = ("vb   memory:%s"):format(bytestr(data.transientVbUsed))
	s[#s+1] = ("ib   memory:%s"):format(bytestr(data.transientIbUsed))
	s[#s+1] = ""
	-- local leaks = math3d.leaks()
	-- if leaks and #leaks >= 0 then
	-- 	s[#s+1] = "-------------------"
	-- 	s[#s+1] = ("math3d leaks: %d"):format(#leaks)
	-- end
	return table.concat(s, "\t\n\t")
end

local wndflags = imgui.flags.Window { "NoResize", "NoScrollbar" }

function m:ui_update()
	imgui.windows.SetNextWindowPos(0,0)
	for _ in imgui_util.windows("Memory Stat", wndflags) do
		imgui.widget.Text(memory_info())
	end
end
