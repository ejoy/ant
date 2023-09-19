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

local function fullname(packname, name)
	return packname .. "|" .. name
end

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

local import_feature

local function genenv(self, packname)
	local env = self.envs[packname]
	if env then
		return env
	end
	env = {}
	self.envs[packname] = env
	local LOADED = {}
	function env.import(filename)
		if LOADED[filename] then
			return false
		end
		LOADED[filename] = true
		local f = self.loader(packname, filename)
		assert(debug.getupvalue(f, 1) == "_ENV")
		debug.setupvalue(f, 1, env)
		f()
		return true
	end
	function env.import_feature(fullname)
		import_feature(self, fullname)
	end
	function env.pipeline(name)
		local contents = {
			value = {},
		}
		local setter = {}
		function setter.pipeline(what)
			assert(type(what) == "string")
			table.insert(contents.value, {"pipeline", what})
			return setter
		end
		function setter.stage(what)
			assert(type(what) == "string")
			table.insert(contents.value, {"stage", what})
			return setter
		end
		local fname = name
		if self.decl.pipeline[fname] then
			error("Redfined pipeline:%s", fname)
		end
		self.decl.pipeline[fname] = contents
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
				fname = fullname(packname, name)
			end
			if self.decl[attr][fname] then
				error(string.format("Redfined %s:%s", attr, fname))
			end
			self.decl[attr][fname] = contents
			return setter
		end
	end
	setmetatable({}, { __index = env , __newindex = readonly })
	return env
end

function import_feature(self, fullname)
	local pname, _ = splitname(fullname)
	if not pname then
		genenv(self, fullname).import "package.ecs"
		return
	end
	local penv = genenv(self, pname)
	penv.import "package.ecs"
	local feature = self.decl.feature[fullname]
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
