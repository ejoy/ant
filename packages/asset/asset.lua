local resource = import_package "ant.resource"
local cr = import_package "ant.compile_resource"
local datalist = require "datalist"

local assetmgr = {}

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
end

local glb = {}

function assetmgr.unload_glb(filename)
	local lst = glb[filename]
	if not lst then
		return
	end
	local tmp = {}
	for i, f in ipairs(lst) do
		tmp[i] = f
	end
	for _, f in ipairs(tmp) do
		resource.unload(f)
		cr.clean(f)
	end
    cr.clean(filename)
end

local function glb_load(path)
	local lst = split(path)
	if #lst <= 1 then
		return
	end
	local t = glb[lst[1]]
	if t then
		t[#t+1] = path
	else
		glb[lst[1]] = {path}
	end
end

local function glb_unload(path)
	local lst = split(path)
	if #lst <= 1 then
		return
	end
	local t = glb[lst[1]]
	if not t then
		return
	end
	for i, v in ipairs(t) do
		if v == path then
			table.remove(t, i)
			if #t == 0 then
				glb[lst[1]] = nil
			end
			break
		end
	end
end

local function push_current_path(w, path)
	w._current_path[#w._current_path+1] = path
end

local function pop_current_path(w)
	w._current_path[#w._current_path] = nil
end

local function get_current_path(w)
	return w._current_path[#w._current_path]
end

local function absolute_path(base, path)
	if path:sub(1,1) == "/" or not base then
		return path
	end
	return base .. (path:match "^%./(.+)$" or path)
end

function assetmgr.resource(world, path)
	local fullpath = absolute_path(get_current_path(world), path)
	resource.load(fullpath, world, true)
    return resource.proxy(fullpath)
end

assetmgr.load_fx = cr.compile_fx

function assetmgr.load_fx_file(fxfile, setting)
	return cr.compile_fx(datalist.parse(cr.read_file(fxfile)), setting)
end

function assetmgr.init()
	local function loader(filename, data)
		local ext = filename:match "[^.]*$"
		glb_load(filename)
		local world = data
		local res
		push_current_path(world, filename:match "^(.-)[^/|]*$")
		res = require("ext_" .. ext).loader(filename, world)
		pop_current_path(world)
		return res
	end
	local function unloader(filename, data, res)
		local ext = filename:match "[^.]*$"
		glb_unload(filename)
		local world = data
		require("ext_" .. ext).unloader(res, world)
	end
	resource.register(loader, unloader)
end

return assetmgr
