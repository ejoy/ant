local fs = require "filesystem"

local loaders = {}

loaders["ozz-animation"] = function (fn)
	local animodule = require "hierarchy.animation"
	local handle = animodule.new_animation(fn)
	return {
		handle = handle
	}
end

loaders["ozz-raw_skeleton"] = function (fn)
	local hiemodule = require "hierarchy"
	local handle = hiemodule.new()
	handle:load(fn)
	return {
		handle = handle
	}
end

loaders["ozz-skeleton"] = function(fn)
	local hiemodule = require "hierarchy"
	local handle = hiemodule.build(fn)
	return {
		handle = handle
	}
end

loaders["ozz-sample-Mesh"] = function(fn)
	local animodule = require "hierarchy.ozzmesh"
	local handle = animodule.new(fn)
	return {
		handle = handle
	}
end

local function find_loader(filepath)
	local f <close> = fs.open(filepath, "rb")
	f:read(1)
	local tag = ("z"):unpack(f:read(16))
	return loaders[tag]
end

local function loader(filename)
	local filepath = fs.path(filename)
	local fn = find_loader(filepath)
	if not fn then
		error "not support type"
		return
	end
	return fn(filepath:localpath():string())
end

local function unloader(res)
	res.handle = nil
end

return {
	loader = loader,
	unloader = unloader
}
