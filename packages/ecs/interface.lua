--[[
	ECS interface , written in .ecs file :

----- interface.ecs ---
import "filename.ecs"
implement "filename.lua"

system "system_name"
	.require_system "other_system"
	.require_system "packname|system_in_packname"
	.stage "stage_a"
	.stage "stage_b"

interface "interface_name"
	.require_system "system_name"
	.method "funcname"

singleton "singleton_name"
	.require_system "system_name"

policy "policy_name"
	.require_system "system_name"
	.require_transform "transform_name"

transform "transform_name"
	.input "aaa"
	.output "bbb"

-----------------------

	Usage:

	local interface = require "interface"

	-- should returns a function
	local function loader(packname, filename)
		local f = loadfile(packname .. "/" .. filename)
		return f
	end

	local parser = interface.new(loader)

	parser:load(packname1, filename)
	parser:load(packname2, filename)
	parser:load(packname3, filename)
	...

	parser:check()
]]

local interface = {}
interface.__index = interface

local parser = {}

local attribute = {
	system = {
		"require_system",
		"require_interface",
		"require_policy",
		"stage",
	},
	policy = {
		"require_system",
		"require_interface",
		"require_policy",
		"require_transform",
	},
	interface = {
		"require_system",
		"require_interface",
		"require_policy",
		"method",
	},
	singleton = {
		"require_system",
		"require_interface",
		"require_policy",
	},
	transform = {
		"input",
		"output",
	},
}

local type_list = {}
local require_map = {}

do	-- init type_list and require_map
	for attrib in pairs(attribute) do
		table.insert(type_list, attrib)
	end

	for _, what in ipairs(type_list) do
		require_map["require_" .. what] = what
	end
end

function parser.new(loader)
	local p = {
		loader = loader,
		implement = {},
	}
	for _, type in ipairs(type_list) do
		p[type] = {}
	end
	return setmetatable( p, interface )
end

local function insert_fileinfo(result)
	local item = result[#result]
	local info = debug.getinfo(3, "Sl")
	item.source = info.source
	item.lineno = info.currentline
end

local function readonly()
	error "_G is readonly"
end

local function fullname(packname, name)
	return packname .. "|" .. name
end

local function attribute_setter(attribs, packname, contents)
	local setter = {}

	for _, a in ipairs(attribs) do
		if require_map[a] then
			setter[a] = function(what)
				assert(type(what) == "string")
				if not what:find("|",1,true) then
					what = fullname(packname, what)
				end
				table.insert(contents, {a, what})
				return setter
			end
		else
			setter[a] = function(what)
				assert(type(what) == "string")
				table.insert(contents, {a, what})
				return setter
			end
		end
	end

	return setter
end

local load_interface do
	local genenv
	load_interface = function (self, packname, filename, result)
		result.loaded[filename] = true
		local f = self.loader(packname, filename)
		assert(debug.getupvalue(f,1) == "_ENV")
		debug.setupvalue(f,1,genenv(self, packname, result))
		f()
		return result
	end

	genenv = function (self, packname, result)
		local api = {}
		function api.import(filename)
			if result.loaded[filename] then
				return
			end
			load_interface(self, packname, filename, result)
		end
		function api.implement(filename)
			table.insert(result, { command = "implement", value = fullname(packname, filename) })
			insert_fileinfo(result)
		end
		function api.system(name)
			local contents = {}
			local system_setter = attribute_setter(attribute.system, packname, contents)
			table.insert(result, { command = "system", name = fullname(packname, name), value = contents })
			insert_fileinfo(result)
			return system_setter
		end
		return setmetatable( {}, { __index = api , __newindex = readonly } )
	end
end

local function merge_all_results(results)
	local r = { transform = {}, implement = {} }
	for _, what in ipairs(type_list) do
		r[what] = {}
	end

	for _, item in ipairs(results) do
		local m = r[item.command]
		if item.name then
			if m[item.name] ~= nil then
				error(string.format("Redfined %s:%s in %s(%d), Already defined at %s(%d)",
					item.command, item.name, item.source, item.lineno, m[item.name].source, m[item.name].lineno))
			end
			m[item.name] = item
		else
			table.insert(m, item)
		end
	end
	return r
end

local function merge(output, input, list)
	for name, item in pairs(input) do
		local value = {}
		for _, attrib in ipairs(list) do
			value[attrib] = {}
		end
		output[name] = value
		for _, tuple in ipairs(item.value) do
			table.insert(value[tuple[1]], tuple[2])
		end
	end
end

local function merge_result(self, result)
	for _, item in ipairs(result.implement) do
		table.insert(self.implement, item.value)
	end

	for _, what in ipairs(type_list) do
		merge(self[what], result[what], attribute[what])
	end
end

function interface:load(packname, filename)
	local results = load_interface(self, packname, filename,  { loaded = {} })
	local r = merge_all_results(results)
	merge_result(self, r)
	return r
end

local function check(tbl, r)
	for name, content in pairs(tbl) do
		for what, list in pairs(content) do
			local check = require_map[what]
			if check then
				-- need check
				for _, require_name in ipairs(list) do
					if r[check][require_name] == nil then
						error(string.format("Not found: %s",require_name))
					end
				end
			end
		end
	end
end

function interface:check()
	for _, what in ipairs(type_list) do
		check(self[what], self)
	end
end

return parser
