local resource = import_package "ant.resource"

local assetmgr = {}
assetmgr.__index = assetmgr

local ext_bin = {
	fx      = true,
	texture = true,
	ozz     = true,
	meshbin = true,
}

local ext_tmp = {
	rendermesh 	= true,
	glbmesh   	= true,
	dynamicfx   = true,
}

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
end

local glb = {}

function assetmgr.unload_glb(filename)
	local cr  = import_package "ant.compile_resource"
	local lst = glb[filename]
	if not lst then
		return
	end
	for _, f in ipairs(lst) do
		resource.unload(f)
		cr.clean(f)
	end
    cr.clean(filename)
	glb[filename] = nil
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

local function resource_load(fullpath, resdata, lazyload)
	local filename = fullpath:match "[^:]+"
	resource.load(filename, resdata, lazyload)
	return fullpath
end

function assetmgr.load(key, resdata)
    return resource.proxy(resource_load(key, resdata, false))
end

function assetmgr.resource(world, fullpath)
    return resource.proxy(resource_load(fullpath, world, true))
end

function assetmgr.init()
	local function loader(ext, filename, data)
		if ext_tmp[ext] then
			return require("ext_" .. ext).loader(data)
		end
		glb_load(filename)
		if ext_bin[ext] then
			return require("ext_" .. ext).loader(filename)
		end
		local world = data
		return world:prefab_init(ext, filename)
	end
	local function unloader(ext, res, filename, data)
		if ext_tmp[ext] then
			require("ext_" .. ext).unloader(res)
			return
		end
		glb_unload(filename)
		if ext_bin[ext] then
			require("ext_" .. ext).unloader(res)
			return
		end
		local world = data
		world:prefab_delete(ext, res)
	end
	resource.register(loader, unloader)
end

assetmgr.patch = resource.patch

local resource_cache = {}
function assetmgr.generate_resource_name(restype, name)
	local key = ("//res.%s/%s"):format(restype, name)
	local idx = resource_cache[key]
	if idx == nil then
		resource_cache[key] = 0
		return key
	end

	idx = idx + 1
	resource_cache[key] = idx
	local n, ext = name:match "([^.]+)%.(.+)$"
	return ("//res.%s/%s%d.%s"):format(restype, n, idx, ext)
end

return assetmgr
