local lfs = require "filesystem.local"
local cr = import_package "ant.compile_resource"
local loaders = {}

loaders["ozz-animation"] = function (fn)
	local animodule = require "hierarchy.animation"
	local handle = animodule.new_animation(fn)
	local scale = 1     -- TODO
	local looptimes = 0 -- TODO
	return {
		_handle = handle,
		_sampling_cache = animodule.new_sampling_cache(),
		_duration = handle:duration() * 1000. / scale,
		_max_ratio = looptimes > 0 and looptimes or math.maxinteger,
	}
end

loaders["ozz-raw_skeleton"] = function (fn)
	local hiemodule = require "hierarchy"
	local handle = hiemodule.new()
	handle:load(fn)
	return {
		_handle = handle
	}
end

loaders["ozz-skeleton"] = function(fn)
	local hiemodule = require "hierarchy"
	local handle = hiemodule.build(fn)
	return {
		_handle = handle
	}
end

loaders["ozz-sample-Mesh"] = function(fn)
	local animodule = require "hierarchy.ozzmesh"
	local handle = animodule.new(fn)
	return {
		_handle = handle
	}
end

local function find_loader(localfilepath)
	local f <close> = lfs.open(localfilepath, "rb")
	f:read(1)
	local tag = ("z"):unpack(f:read(16))
	return loaders[tag]
end

local function loader(filename)
	local localfilename = cr.compile(filename)
	local fn = find_loader(localfilename)
	if not fn then
		error "not support type"
		return
	end
	return fn(localfilename:string())
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
