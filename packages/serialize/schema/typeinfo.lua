local fs = require "filesystem"
local createschema = require "schema.schema"
local get_modules = require "schema.modules"

local GeneralTable = {}
local function GeneralFunction()
    return GeneralTable
end
setmetatable(GeneralTable, {
	__newindex = function() end,
	__index = GeneralFunction,
	__call = GeneralFunction,
	__div = GeneralFunction,
	__mul = GeneralFunction,
	__unm = GeneralFunction,
})

local world = GeneralTable
local env = setmetatable({
	import_package = GeneralFunction,
	require = GeneralFunction,
}, {__index = _G})

local function load_package(ecs, path)
	local modules = get_modules(path, {"*.lua"})
	for _, file in ipairs(modules) do
		local m, err = fs.loadfile(file, 't', env)
		if not m then
			error(("module '%s' load failed:%s"):format(path:string(), err))
		end
        m(ecs)
	end
end

local function load_packages(ecs, path)
    for dir in path:list_directory() do
        if fs.is_directory(dir) then
            load_package(ecs, dir)
        end
    end
end


local function decl_basetype(schema)
	schema:primtype("tag", true)
	schema:primtype("int", 0)
	schema:primtype("real", 0.0)
	schema:primtype("string", "")
	schema:primtype("boolean", false)
end

return function()
	local schema_data = {}
    local schema = createschema(schema_data)
	local ecs = { world = world }
	local function register(what)
		ecs[what] = GeneralFunction
	end
	register "system"
	register "transform"
	register "policy"
	register "interface"
	ecs.component = function (name)
		return schema:type(name)
	end
	ecs.component_alias = function (name, ...)
		return schema:typedef(name, ...)
	end
	ecs.tag = function (name)
		ecs.component_alias(name, "tag")
	end
	decl_basetype(schema)
    load_packages(ecs, fs.path "/pkg")
    return schema_data.map
end
