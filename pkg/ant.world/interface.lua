local attribute = {
	system = {
		"implement",
	},
	policy = {
		"include_policy",
		"component",
		"component_opt",
	},
	component = {
		"implement",
		"type",
		"size",
		"field",
	},
	feature = {
		"import",
	},
}

local function readonly()
	error "_G is readonly"
end

local fastio = require "fastio"
local vfs = require "vfs"

local function package_loadfile(packname, file, env)
	local path = "/pkg/"..packname.."/"..file
	local mem, symbol = vfs.read(path)
	if not mem then
		error(("file '%s' not found"):format(path))
	end
	local func, err = fastio.loadlua(mem, symbol, env)
	if not func then
		error(("error loading file '%s':\n\t%s"):format(path, err))
	end
	return func
end

local import_feature

local function genenv(envs, decl, newdecl, packname)
	local env = envs[packname]
	if env then
		return env
	end
	env = {}
	envs[packname] = env
	local LOADED = {}
	function env.import(filename)
		if LOADED[filename] then
			return
		end
		LOADED[filename] = true
		local func = package_loadfile(packname, filename, env)
		func()
	end
	function env.import_feature(fullname)
		import_feature(envs, decl, newdecl, fullname)
	end
	function env.pipeline(name)
		if decl.pipeline[name] then
			error("Redfined pipeline:%s", name)
		end
		local value = {}
		local setter = {}
		function setter.pipeline(what)
			assert(type(what) == "string")
			value[#value+1] = {"pipeline", what}
			return setter
		end
		function setter.stage(what)
			assert(type(what) == "string")
			value[#value+1] = {"stage", what}
			return setter
		end
		decl.pipeline[name] = value
		return setter
	end
	for attr, attribs in pairs(attribute) do
		env[attr] = function (name)
			local contents = {
				packname = packname,
			}
			local setter = {}
			for _, a in ipairs(attribs) do
				contents[a] = {}
				setter[a] = function(what)
					assert(type(what) == "string")
					table.insert(contents[a], what)
					return setter
				end
			end
			local fname
			if attr == "component" then
				fname = name
			else
				fname = packname .. "|" .. name
			end
			if decl[attr][fname] then
				error(string.format("Redfined %s:%s", attr, fname))
			end
			decl[attr][fname] = contents
			if newdecl[attr] then
				newdecl[attr][fname] = contents
			end
			return setter
		end
	end
	setmetatable({}, { __index = env , __newindex = readonly })
	return env
end

function import_feature(envs, decl, newdecl, fullname)
	local pname = fullname:match "^([^|]*)|.*$"
	if not pname then
		genenv(envs, decl, newdecl, fullname).import "package.ecs"
		return
	end
	local penv = genenv(envs, decl, newdecl, pname)
	penv.import "package.ecs"
	local feature = decl.feature[fullname]
	if not feature then
		error(("invalid feature name: `%s`."):format(fullname))
	end
	for _, fname in ipairs(feature.import) do
		penv.import(fname)
	end
end

return {
	import_feature = import_feature,
}
