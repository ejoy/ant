local ecs = require "ecs.core"

local function get_attrib(opt, inout)
	if opt == nil then
		return { exist = true }
	end
	local desc = {}
	if opt == "?" then
		desc.opt = true
	else
		assert(opt == ":")
	end
	if inout == "in" then
		desc.r = true
	elseif inout == "out" then
		desc.w = true
	elseif inout == "update" then
		desc.r = true
		desc.w = true
	elseif inout == "exist" then
		desc.exist = true
		assert(not desc.opt)
	else
		assert(inout == "temp")
	end
	return desc
end

local function cache_world(obj, k)
	local c = {
		typenames = {},
		id = 0,
		select = {},
	}

	local function gen_select_pat(pat)
		local typenames = c.typenames
		local desc = {}
		local idx = 1
		for token in pat:gmatch "[^ ]+" do
			local key, padding = token:match "^([_%w]+)(.*)"
			assert(key, "Invalid pattern")
			local opt, inout
			if padding ~= "" then
				opt, inout = padding:match "^([:?])(%l+)$"
				assert(opt, "Invalid pattern")
			end
			local tc = assert(typenames[key])
			local a = get_attrib(opt, inout)
			a.name = tc.name
			a.id = tc.id
			a.type = tc.type
			local n = #tc
			for i=1,#tc do
				a[i] = tc[i]
			end
			desc[idx] = a
			idx = idx + 1
		end
		return desc
	end

	local function cache_select(cache, pat)
		local pat_desc = gen_select_pat(pat)
		cache[pat] = k:_groupiter(pat_desc)
		return cache[pat]
	end

	setmetatable(c.select, {
		__mode = "kv",
		__index = cache_select,
		})

	obj[k] = c
	return c
end

local context = setmetatable({}, { __index = cache_world })
local typeid = {
	int = assert(ecs._TYPEINT),
	float = assert(ecs._TYPEFLOAT),
	bool = assert(ecs._TYPEBOOL),
}
local typesize = {
	[typeid.int] = 4,
	[typeid.float] = 4,
	[typeid.bool] = 1,
}

local typepack = {
	[typeid.int] = 'i4',
	[typeid.float] = 'f',
	[typeid.bool] = 'B',
}

local M = ecs._METHODS

do	-- newtype
	local function parse(s)
		-- s is "name:typename"
		local name, typename = s:match "([%w_]+):(%l+)"
		local typeid = assert(typeid[typename])
		return { typeid, name }
	end

	local function align(c, field)
		local t = field[1]
		local size = c.size
		if t == typeid.int or t == typeid.float then
			local offset = ((size + 3) & ~3)
			c.size = offset + 4
			field[3] = offset
		elseif t == typeid.bool then
			c.size = size + 1
			field[3] = size
		else
			error("Invalid type " .. t)
		end
		return field
	end

	local function align_struct(c, t)
		if t == typeid.int or t == typeid.float then
			c.size = ((c.size + 3) & ~3)
		end
	end

	function M:register(typeclass)
		local name = assert(typeclass.name)
		local ctx = context[self]
		local typenames = ctx.typenames
		local id = ctx.id + 1
		assert(typenames[name] == nil and id <= ecs._MAXTYPE)
		ctx.id = id
		local c = {
			id = id,
			name = name,
			size = 0,
		}
		for i, v in ipairs(typeclass) do
			c[i] = align(c, parse(v))
		end
		local ttype = typeclass.type
		if  ttype == "lua" then
			assert(c.size == 0)
			c.size = ecs._LUAOBJECT
			c.islua = true
		elseif c.size > 0 then
			align_struct(c, typeclass[1][1])
			local pack = "!4="
			for i = 1, #c do
				pack = pack .. typepack[c[i][1]]
			end
			c.pack = pack
		else
			-- size == 0, one value
			if ttype then
				local t = assert(typeid[typeclass.type])
				c.type = t
				c.size = typesize[t]
				c.pack = typepack[t]
				c[1] = { t, "v", 0 }
			else
				c.tag = true
			end
		end
		typenames[name] = c
		self:_newtype(id, c.size)
	end
end

local mapbool = {
	[true] = 1,
	[false] = 0,
}

function M:new(obj)
	local eid = self:_newentity()
	local typenames = context[self].typenames
	for k,v in pairs(obj) do
		local tc = typenames[k]
		if not tc then
			error ("Invalid key : ".. k)
		end
		if tc.islua then
			self:_addcomponent(eid, tc.id, v)
		elseif tc.tag then
			assert(tc.size == 0)
			self:_addcomponent(eid, tc.id)
		elseif tc.type then
			self:_addcomponent(eid, tc.id, string.pack(tc.pack, mapbool[v] or v))
		else
			local tmp = {}
			for i, f in ipairs(tc) do
				tmp[i] = v[f[2]]
			end
			self:_addcomponent(eid, tc.id, string.pack(tc.pack, table.unpack(tmp)))
		end
	end
end

function M:context(t)
	local typenames = context[self].typenames
	local id = {}
	for i, name in ipairs(t) do
		local tc = typenames[name]
		if not tc then
			error ("Invalid component name " .. name)
		end
		id[i] = tc.id
	end
	return self:_context(id)
end

function M:select(pat)
	return context[self].select[pat]()
end

function M:clear(name)
	local id = assert(context[self].typenames[name].id)
	self:_clear(id)
end

function M:sort(sorted, name)
	local ctx = context[self]
	local typenames = ctx.typenames
	local t = assert(typenames[name])
	assert(t.type == typeid.int or (#t == 1 and t[1][1] == typeid.float))
	local stype = typenames[sorted]
	if stype == nil then
		local id = ctx.id + 1
		assert(id <= ecs._MAXTYPE)
		ctx.id = id
		stype = {
			id = id,
			name = sorted,
			size = ecs._ORDERKEY,
			tag = true
		}
		self:_newtype(id, stype.size)
		typenames[sorted] = stype
	else
		assert(stype.size == ecs._ORDERKEY)
	end
	self:_sortkey(stype.id, t.id)
end

function ecs.world()
	local w = ecs._world()
	context[w].typenames.REMOVED = {
		name = "REMOVED",
		id = ecs._REMOVED,
		size = 0,
		tag = true,
	}
	return w
end

return ecs
