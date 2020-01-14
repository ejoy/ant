local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local renderpkg = import_package "ant.render"
local skypkg = import_package "ant.sky"
local serialize = import_package 'ant.serialize'
local imgui = require "imgui.ant"
local fs = require "filesystem"

local skyutil = skypkg.util
local ms = mathpkg.stack
local mu = mathpkg.util
local mc = mathpkg.constant

local lu = renderpkg.light
local cu = renderpkg.components
local defaultcomp = renderpkg.default

local m = ecs.system "model_review_system"

m.require_policy "ant.sky|procedural_sky"
m.require_policy "ant.serialize|serialize"
m.require_policy "ant.bullet|collider.capsule"
m.require_policy "ant.render|mesh"
m.require_policy "ant.render|render"
m.require_policy "ant.render|name"
m.require_policy "ant.render|shadow_cast"
m.require_policy "ant.render|light.directional"
m.require_policy "ant.render|light.ambient"
m.require_system "ant.imguibase|imgui_system"
m.require_system "ant.camera_controller|camera_system"

local function create_light()
	lu.create_directional_light_entity(world, "direction light", 
		{1,1,1,1}, 2, mu.to_radian{60, 50, 0, 0})
	lu.create_ambient_light_entity(world, "ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

local function create_camera()
    local fbsize = world.args.fb_size
    local frustum = defaultcomp.frustum(fbsize.w, fbsize.h)
    frustum.f = 300
    world:pub {"spawn_camera", "test_main_camera", {
        type    = "",
        eyepos  = {0, 3, -10, 1},
        viewdir = mc.T_ZAXIS,
        updir   = mc.T_YAXIS,
        frustum = frustum,
    }}
end

function m:init()
	create_camera()
	create_light()
	skyutil.create_procedural_sky(world, {follow_by_directional_light=false})
	cu.create_plane_entity(world, 
		mu.srt{50, 1, 50, 0},
		fs.path "/pkg/ant.resources/depiction/materials/test/mesh_shadow.material", 
		{0.8, 0.8, 0.8, 1},
		"test shadow plane")

	local function load_file(file)
		local f = assert(fs.open(fs.path(file), 'r'))
		local data = f:read 'a'
		f:close()
		return data
	end
	world:create_entity(load_file 'res/door.txt')
	world:create_entity(load_file 'res/fence.txt')
	world:create_entity(load_file 'res/player.txt')
end

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

function m:ui_update()
	local widget = imgui.widget
	for _ in imgui_windows("Test") do
		widget.Text(memory_info())
	end
end
