local ecs = ...

local mathpkg = import_package "ant.math"
local imgui = require "imgui.ant"
local rp3d = require "rp3d.core"
local ms = mathpkg.stack

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
	s[#s+1] = ("math  memory:%s"):format(bytestr(ms:stacksize()))
	s[#s+1] = ("imgui memory:%s"):format(bytestr(imgui.ant.get_memory()))
	s[#s+1] = ("rp3d  memory:%s"):format(bytestr(rp3d.memory()))
	s[#s+1] = "-------------------"
	local data = bgfx.get_stats "m"
	s[#s+1] = ("rt   memory:%s"):format(bytestr(data.rtMemoryUsed))
	s[#s+1] = ("tex  memory:%s"):format(bytestr(data.textureMemoryUsed))
	s[#s+1] = ("vb   memory:%s"):format(bytestr(data.transientVbUsed))
	s[#s+1] = ("ib   memory:%s"):format(bytestr(data.transientIbUsed))
	s[#s+1] = ""
	local leaks = ms:leaks()
	if leaks and #leaks >= 0 then
		s[#s+1] = "-------------------"
		s[#s+1] = ("math3d leaks: %d"):format(#leaks)
	end
	return table.concat(s, "\t\n\t")
end

local function defer(f)
    local toclose = setmetatable({}, { __close = f })
    return function (_, w)
        if not w then
            return toclose
        end
    end, nil, nil, toclose
end

local function imgui_windows(...)
	imgui.windows.Begin(...)
	return defer(function()
		imgui.windows.End()
	end)
end

local wndflags = imgui.flags.Window { "NoResize", "NoScrollbar" }

function m:ui_update()
	imgui.windows.SetNextWindowPos(0,0)
	for _ in imgui_windows("Memory Stat", wndflags) do
		imgui.widget.Text(memory_info())
	end
end
