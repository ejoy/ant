local interface = {}
interface.__index = interface

local parser = {}

local attribute = {
	pipeline = {
		"pipeline",
		"stage",
	},
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
	import_feature = {
	},
}

local ATTRIBUTE_IGNORE_PACKAGE <const> = 0
local ATTRIBUTE_IGNORE_FILENAME <const> = 1
local ATTRIBUTE_NO_PACKAGE <const> = 2

local attribute_type = {
	pipeline = ATTRIBUTE_NO_PACKAGE,
	none = ATTRIBUTE_NO_PACKAGE,
	component = ATTRIBUTE_NO_PACKAGE,
	feature = ATTRIBUTE_IGNORE_PACKAGE,
	system = ATTRIBUTE_IGNORE_PACKAGE,
	policy = ATTRIBUTE_IGNORE_PACKAGE,
	import_feature = ATTRIBUTE_IGNORE_FILENAME,
}

local check_map = {
	include_policy = "policy",
	component = "component",
	import_feature = "import_feature",
	import = "none",
	pipeline = "none",
	stage = "none",
}

local type_list = {}
local packspace_map = {}

do	-- init type_list
	for attrib in pairs(attribute) do
		table.insert(type_list, attrib)
	end

	for what, attrib in pairs(check_map) do
		packspace_map[what] = attribute_type[attrib]
	end
end

function parser.new(loader)
	local p = {
		loaded = {},
		loader = loader,
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
		if packspace_map[a] == ATTRIBUTE_IGNORE_PACKAGE then
			setter[a] = function(what)
				assert(type(what) == "string")
				if not what:find("|",1,true) then
					what = fullname(packname, what)
				end
				table.insert(contents, {a, what})
				return setter
			end
		elseif packspace_map[a] == ATTRIBUTE_NO_PACKAGE then
			setter[a] = function(what)
				assert(type(what) == "string")
				table.insert(contents, {a, what})
				return setter
			end
		elseif packspace_map[a] == ATTRIBUTE_IGNORE_FILENAME then
			setter[a] = function(what)
				assert(type(what) == "string")
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
	load_interface = function (self, current, packname, filename, result)
		if self.loaded[packname.."/"..filename] then
			return
		end
		self.loaded[packname.."/"..filename] = true
		local f = self.loader(current, packname, filename)
		assert(debug.getupvalue(f,1) == "_ENV")
		debug.setupvalue(f,1,genenv(self, packname, result))
		f()
		return result
	end

	genenv = function (self, packname, result)
		local api = {}
		function api.import(filename)
			local pname, fname = packname, filename
			if filename:sub(1,1) == "@" then
				if filename:find "/" then
					pname, fname = filename:match "^@([^/]*)/(.*)$"
				else
					pname = filename:sub(2)
					fname = "package.ecs"
				end
			end
			load_interface(self, packname, pname, fname, result)
		end
		for _, attr in ipairs(type_list) do
			api[attr] = function (name)
				local contents = {}
				local setter = attribute_setter(attribute[attr], packname, contents)
				local fname
				if attribute_type[attr] == ATTRIBUTE_NO_PACKAGE then
					fname = name
				elseif attribute_type[attr] == ATTRIBUTE_IGNORE_PACKAGE then
					fname = fullname(packname, name)
				elseif attribute_type[attr] == ATTRIBUTE_IGNORE_FILENAME then
					fname = name
				else
					assert(false, attr)
				end
				table.insert(result, { command = attr, packname = packname, name = fname, value = contents })
				insert_fileinfo(result)
				return setter
			end
		end
		return setmetatable( {}, { __index = api , __newindex = readonly } )
	end
end

local function merge_all_results(results)
	local r = { implement = {} }
	for _, what in ipairs(type_list) do
		r[what] = {}
	end

	for _, item in ipairs(results) do
		local m = r[item.command]
		if item.name then
			if item.command ~= "import_feature" and m[item.name] ~= nil then
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
		local value = {
			packname = item.packname,
			value = {},
		}
		for _, attrib in ipairs(list) do
			value[attrib] = {}
		end
		output[name] = value
		for _, tuple in ipairs(item.value) do
			if check_map[tuple[1]] then
				table.insert(value.value, tuple)
			end
			table.insert(value[tuple[1]], tuple[2])
		end
	end
end

local function merge_result(self, result)
	for _, what in ipairs(type_list) do
		merge(self[what], result[what], attribute[what])
	end
end

function interface:load(packname, filename)
	local results = load_interface(self, nil, packname, filename, {})
	if results then
		local r = merge_all_results(results)
		merge_result(self, r)
		return r
	end
end

local function check(tbl, r)
	for _, content in pairs(tbl) do
		for what, list in pairs(content) do
			local check = check_map[what]
			if check and check ~= "none" then
				-- need check
				for _, require_name in ipairs(list) do
					if r[check][require_name] == nil then
						if check ~= "import_feature" or what:find("|",1,true) then
							error(string.format("Not found (%s) : %s",check, require_name))
						end
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
