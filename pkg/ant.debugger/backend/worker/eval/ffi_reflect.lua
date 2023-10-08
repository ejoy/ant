--[[ LuaJIT FFI reflection Library ]]
--
--[[ Copyright (C) 2014 Peter Cawley <lua@corsix.org>. All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
--]]
local ffi = require "ffi"
local bit = require "bit"
local reflect = {}

local CTState, init_CTState
local miscmap, init_miscmap

local function gc_str(gcref) -- Convert a GCref (to a GCstr) into a string
	if gcref ~= 0 then
		local ts = ffi.cast("uint32_t*", gcref)
		return ffi.string(ts + 4, ts[3])
	end
end

local typeinfo = ffi.typeinfo or function (id)
	-- ffi.typeof is present in LuaJIT v2.1 since 8th Oct 2014 (d6ff3afc)
	-- this is an emulation layer for older versions of LuaJIT
	local ctype = (CTState or init_CTState()).tab[id]
	return {
		info = ctype.info,
		size = bit.bnot(ctype.size) ~= 0 and ctype.size,
		sib = ctype.sib ~= 0 and ctype.sib,
		name = gc_str(ctype.name),
	}
end

local function memptr(gcobj)
	return tonumber(tostring(gcobj):match "%x*$", 16)
end

init_CTState = function ()
	-- Relevant minimal definitions from lj_ctype.h
	ffi.cdef [[
    typedef struct CType {
      uint32_t info;
      uint32_t size;
      uint16_t sib;
      uint16_t next;
      uint32_t name;
    } CType;

    typedef struct CTState {
      CType *tab;
      uint32_t top;
      uint32_t sizetab;
      void *L;
      void *g;
      void *finalizer;
      void *miscmap;
    } CTState;
  ]]

	-- Acquire a pointer to this Lua universe's CTState
	local co = coroutine.create(function (f, ...) return f(...) end)
	local uintgc = ffi.abi "gc64" and "uint64_t" or "uint32_t"
	local uintgc_ptr = ffi.typeof(uintgc.."*")
	local G = ffi.cast(uintgc_ptr, ffi.cast(uintgc_ptr, memptr(co))[2])
	-- In global_State, `MRef ctype_state` precedes `GCRef gcroot[GCROOT_MAX]`.
	-- We first find (an entry in) gcroot by looking for a metamethod name string.
	local anchor = ffi.cast(uintgc, ffi.cast("const char*", "__index"))
	local i = 0
	while math.abs(tonumber(G[i] - anchor)) > 64 do
		i = i + 1
	end
	-- Since Aug 2013, `GCRef cur_L` has preceded `MRef ctype_state`. Try to find it.
	local ok, i2 = coroutine.resume(co,
		function (coptr)
			for i2 = i - 3, i - 20, -1 do
				if G[i2] == coptr then return i2 end
			end
		end, memptr(co))
	if ok and i2 then
		-- If we found it, work forwards looking for something resembling ctype_state.
		for i = i2 + 2, i - 1 do
			local Gi = G[i]
			if Gi ~= 0 and bit.band(Gi, 3) == 0 then
				CTState = ffi.cast("CTState*", Gi)
				if ffi.cast(uintgc_ptr, CTState.g) == G then
					return CTState
				end
			end
		end
	else
		-- Otherwise, work backwards looking for something resembling ctype_state.
		-- Note that since Jun 2020, this walks over the PRNGState, which is bad.
		for i = i - 1, 0, -1 do
			local Gi = G[i]
			if Gi ~= 0 and bit.band(Gi, 3) == 0 then
				CTState = ffi.cast("CTState*", Gi)
				if ffi.cast(uintgc_ptr, CTState.g) == G then
					return CTState
				end
			end
		end
	end
end

init_miscmap = function ()
	-- Acquire the CTState's miscmap table as a Lua variable
	local t = {};
	t[0] = t
	local uptr = ffi.cast("uintptr_t", (CTState or init_CTState()).miscmap)
	if ffi.abi "gc64" then
		local tvalue = ffi.cast("uint64_t**", memptr(t))[2]
		tvalue[0] = bit.bor(bit.lshift(bit.rshift(tvalue[0], 47), 47), uptr)
	else
		local tvalue = ffi.cast("uint32_t*", memptr(t))[2]
		ffi.cast("uint32_t*", tvalue)[ffi.abi "le" and 0 or 1] = ffi.cast("uint32_t", uptr)
	end
	miscmap = t[0]
	return miscmap
end

-- Information for unpacking a `struct CType`.
-- One table per CT_* constant, containing:
-- * A name for that CT_
-- * Roles of the cid and size fields.
-- * Whether the sib field is meaningful.
-- * Zero or more applicable boolean flags.
local CTs = {
	[0] =
	{ "int",
		"", "size", false,
		{ 0x08000000, "bool" },
		{ 0x04000000, "float",   "subwhat" },
		{ 0x02000000, "const" },
		{ 0x01000000, "volatile" },
		{ 0x00800000, "unsigned" },
		{ 0x00400000, "long" },
	},
	{ "struct",
		"", "size", true,
		{ 0x02000000, "const" },
		{ 0x01000000, "volatile" },
		{ 0x00800000, "union",   "subwhat" },
		{ 0x00100000, "vla" },
	},
	{ "ptr",
		"element_type", "size", false,
		{ 0x02000000, "const" },
		{ 0x01000000, "volatile" },
		{ 0x00800000, "ref",     "subwhat" },
	},
	{ "array",
		"element_type", "size", false,
		{ 0x08000000, "vector" },
		{ 0x04000000, "complex" },
		{ 0x02000000, "const" },
		{ 0x01000000, "volatile" },
		{ 0x00100000, "vla" },
	},
	{ "void",
		"", "size", false,
		{ 0x02000000, "const" },
		{ 0x01000000, "volatile" },
	},
	{ "enum",
		"type", "size", true,
	},
	{ "func",
		"return_type", "nargs", true,
		{ 0x00800000, "vararg" },
		{ 0x00400000, "sse_reg_params" },
	},
	{ "typedef", -- Not seen
		"element_type", "", false,
	},
	{ "attrib", -- Only seen internally
		"type", "value", true,
	},
	{ "field",
		"type", "offset", true,
	},
	{ "bitfield",
		"", "offset", true,
		{ 0x08000000, "bool" },
		{ 0x02000000, "const" },
		{ 0x01000000, "volatile" },
		{ 0x00800000, "unsigned" },
	},
	{ "constant",
		"type", "value", true,
		{ 0x02000000, "const" },
	},
	{ "extern", -- Not seen
		"CID", "", true,
	},
	{ "kw", -- Not seen
		"TOK", "size",
	},
}

-- Set of CType::cid roles which are a CTypeID.
local type_keys = {
	element_type = true,
	return_type = true,
	value_type = true,
	type = true,
}

-- Create a metatable for each CT.
local metatables = {
}
for _, CT in ipairs(CTs) do
	local what = CT[1]
	local mt = { __index = {} }
	metatables[what] = mt
end

-- Logic for merging an attribute CType onto the annotated CType.
local CTAs = {
	[0] =
		function (a, refct) error("TODO: CTA_NONE") end,
	function (a, refct) error("TODO: CTA_QUAL") end,
	function (a, refct)
		a = 2 ^ a.value
		refct.alignment = a
		refct.attributes.align = a
	end,
	function (a, refct)
		refct.transparent = true
		refct.attributes.subtype = refct.typeid
	end,
	function (a, refct) refct.sym_name = a.name end,
	function (a, refct) error("TODO: CTA_BAD") end,
}

-- C function calling conventions (CTCC_* constants in lj_refct.h)
local CTCCs = {
	[0] =
	"cdecl",
	"thiscall",
	"fastcall",
	"stdcall",
}

local function refct_from_id(id) -- refct = refct_from_id(CTypeID)
	local ctype = typeinfo(id)
	if not ctype then
		return nil
	end
	local CT_code = bit.rshift(ctype.info, 28)
	local CT = CTs[CT_code]
	local what = CT[1]
	local refct = setmetatable({
		what = what,
		typeid = id,
		name = ctype.name,
	}, metatables[what])

	-- Interpret (most of) the CType::info field
	for i = 5, #CT do
		if bit.band(ctype.info, CT[i][1]) ~= 0 then
			if CT[i][3] == "subwhat" then
				refct.what = CT[i][2]
			else
				refct[CT[i][2]] = true
			end
		end
	end
	if CT_code <= 5 then
		refct.alignment = bit.lshift(1, bit.band(bit.rshift(ctype.info, 16), 15))
	elseif what == "func" then
		refct.convention = CTCCs[bit.band(bit.rshift(ctype.info, 16), 3)]
	end

	if CT[2] ~= "" then -- Interpret the CType::cid field
		local k = CT[2]
		local cid = bit.band(ctype.info, 0xffff)
		if type_keys[k] then
			if cid == 0 then
				cid = nil
			else
				cid = refct_from_id(cid)
			end
		end
		refct[k] = cid
	end

	if CT[3] ~= "" then -- Interpret the CType::size field
		local k = CT[3]
		refct[k] = ctype.size or (k == "size" and "none")
	end

	if what == "attrib" then
		-- Merge leading attributes onto the type being decorated.
		local CTA = CTAs[bit.band(bit.rshift(ctype.info, 16), 0xff)]
		if refct.type then
			local ct = refct.type
			ct.attributes = {}
			CTA(refct, ct)
			ct.typeid = refct.typeid
			refct = ct
		else
			refct.CTA = CTA
		end
	elseif what == "bitfield" then
		-- Decode extra bitfield fields, and make it look like a normal field.
		refct.offset = refct.offset + bit.band(ctype.info, 127) / 8
		refct.size = bit.band(bit.rshift(ctype.info, 8), 127) / 8
		refct.type = {
			what = "int",
			bool = refct.bool,
			const = refct.const,
			volatile = refct.volatile,
			unsigned = refct.unsigned,
			size = bit.band(bit.rshift(ctype.info, 16), 127),
		}
		refct.bool, refct.const, refct.volatile, refct.unsigned = nil
	end

	if CT[4] then -- Merge sibling attributes onto this type.
		while ctype.sib do
			local entry = typeinfo(ctype.sib)
			if CTs[bit.rshift(entry.info, 28)][1] ~= "attrib" then break end
			if bit.band(entry.info, 0xffff) ~= 0 then break end
			local sib = refct_from_id(ctype.sib)
			sib:CTA(refct)
			ctype = entry
		end
	end

	return refct
end

local function sib_iter(s, refct)
	repeat
		local ctype = typeinfo(refct.typeid)
		if not ctype.sib then return end
		refct = refct_from_id(ctype.sib)
	until refct.what ~= "attrib" -- Pure attribs are skipped.
	return refct
end

local function siblings(refct)
	-- Follow to the end of the attrib chain, if any.
	while refct.attributes do
		refct = refct_from_id(refct.attributes.subtype or typeinfo(refct.typeid).sib)
	end

	return sib_iter, nil, refct
end

metatables.struct.__index.members = siblings
metatables.func.__index.arguments = siblings
metatables.enum.__index.values = siblings

local function find_sibling(refct, name)
	local num = tonumber(name)
	if num then
		for sib in siblings(refct) do
			if num == 1 then
				return sib
			end
			num = num - 1
		end
	else
		for sib in siblings(refct) do
			if sib.name == name then
				return sib
			end
		end
	end
end

metatables.struct.__index.member = find_sibling
metatables.func.__index.argument = find_sibling
metatables.enum.__index.value = find_sibling

local ti_cache = {}

local function typeof(id)
	local ti = ti_cache[id]
	if ti then
		return ti
	end
	ti = refct_from_id(id)
	ti_cache[id] = ti
	return ti
end

function reflect.typeof(x) -- refct = reflect.typeof(ct)
	local id = tonumber(ffi.typeof(x))
	return typeof(id)
end

function reflect.getmetatable(x) -- mt = reflect.getmetatable(ct)
	return (miscmap or init_miscmap())[-tonumber(ffi.typeof(x))]
end

local linker_cache = {}

local function get_typedef_linker(typeinfo)
	local id = typeinfo.typeid
	local linker_id = linker_cache[id]
	if linker_id then
		return typeof(linker_id)
	end
	for id = 96, 65536, 1 do
		local ti = typeof(id)
		if not ti then
			return
		end
		if ti.what == 'typedef' then
			if ti.element_type.typeid == typeinfo.typeid then
				linker_cache[id] = ti.typeid
				return ti
			end
		end
	end
end

---@type table<ffi.typeinfo.what,function>
local showtypename = {}
---@param intinfo ffi.intinfo
function showtypename.int(intinfo)
	if intinfo.bool then
		return "boolean"
	end
	local n = intinfo.unsigned and "u" or ""
	local t = {
		[1] = "int8",
		[2] = "int16",
		[4] = "int32",
		[8] = "int64",
	}
	return n..t[intinfo.size]
end

---@param floatinfo ffi.floatinfo
function showtypename.float(floatinfo)
	return floatinfo.size == 8 and "double" or "float"
end

---@param enuminfo ffi.enuminfo
function showtypename.enum(enuminfo)
	return "enum "..(enuminfo.name or get_typedef_linker(enuminfo).name or "unknown")
end

---@param ptrinfo ffi.ptrinfo
function showtypename.ptr(ptrinfo)
	if ptrinfo.element_type.what == 'func' then
		return showtypename[ptrinfo.element_type.what](ptrinfo.element_type, nil, "*")
	end
	return showtypename[ptrinfo.element_type.what](ptrinfo.element_type).."*"
end

function showtypename.void(voidinfo)
	return "void"
end

---@param refinfo ffi.refinfo
function showtypename.ref(refinfo)
	if refinfo.element_type.what == 'func' then
		return showtypename[refinfo.element_type.what](refinfo.element_type, nil, "&")
	else
	end
	return showtypename[refinfo.element_type.what](refinfo.element_type).."&"
end

---@param arrayinfo ffi.arrayinfo
function showtypename.array(arrayinfo, value)
	local name = showtypename[arrayinfo.element_type.what](arrayinfo.element_type)
	if arrayinfo.vla then
		return name.."["..(value and ffi.sizeof(value) or "?").."]"
	else
		return name.."["..
			arrayinfo.size / arrayinfo.element_type.size.."]"
	end
end

---@param structinfo ffi.structinfo
function showtypename.struct(structinfo)
	local name = structinfo.name
	if not name then
		local linker = get_typedef_linker(structinfo)
		name = linker and linker.name or "[annotated]"
	end
	return "struct "..name
end

---@param unioninfo ffi.unioninfo
function showtypename.union(unioninfo)
	local name = unioninfo.name
	if not name then
		local linker = get_typedef_linker(unioninfo)
		name = linker and linker.name or "[annotated]"
	end
	return "union "..name
end

---@param funcinfo ffi.funcinfo
function showtypename.func(funcinfo, _, attributes)
	local arguments
	for reflc in funcinfo:arguments() do
		---@cast reflc + ffi.fieldinfo
		if arguments then
			arguments = arguments..", "
		else
			arguments = ""
		end
		arguments = arguments..showtypename[reflc.type.what](reflc.type)
		if reflc.name then
			arguments = arguments.." "..reflc.name
		end
	end
	local name = (funcinfo.sym_name or funcinfo.name or "unknown")
	if attributes then
		if name == 'unknown' then
			name = "("..attributes..")"
		else
			name = "("..attributes..name..")"
		end
	end
	local result = showtypename[funcinfo.return_type.what](funcinfo.return_type)
	local convention = (funcinfo.convention and funcinfo.convention ~= 'cdecl' and (funcinfo.convention.." ") or "")
	return result.." "..convention..name.."("..arguments..")"
end

---@type table<ffi.typeinfo.what,function>
local showtypevalue = {}
---@param intinfo ffi.intinfo
function showtypevalue.int(intinfo, v)
	if intinfo.bool then
		return tonumber(v) == 1 and true or false
	end
	return tonumber(v)
end

---@param floatinfo ffi.floatinfo
function showtypevalue.float(floatinfo, v)
	return tonumber(v)
end

---@param enuminfo ffi.enuminfo
function showtypevalue.enum(enuminfo, v)
	v = tonumber(v)
	for reflc in enuminfo:values() do
		if v == reflc.value then
			return reflc.name
		end
	end
	return v
end

local intptr_t = ffi.typeof("intptr_t")
function showtypevalue.ptr(_, v)
	v = tonumber(ffi.cast(intptr_t, v))
	if v == 0 then
		return "nullptr"
	end
	return string.format("0x%x", v)
end

function showtypevalue.func(_, v)
	v = tonumber(ffi.cast(intptr_t, v))
	if v == 0 then
		return "nullptr"
	end
	return string.format("0x%x", v)
end

local function gettypename(typeinfo, v)
	local fn = showtypename[typeinfo.what]
	if fn then
		return fn(typeinfo, v)
	else
		return typeinfo.name
	end
end

local function getshowvalue(typeinfo, v)
	local fn = showtypevalue[typeinfo.what]
	if fn then
		return fn(typeinfo, v)
	end
end

function reflect.shortvalue(v)
	local typeinfo = reflect.typeof(v)
	return getshowvalue(typeinfo, v)
end

function reflect.shorttypename(v)
	local typeinfo = reflect.typeof(v)
	if typeinfo.what == 'ptr' or typeinfo.what == 'ref' then
		typeinfo = typeinfo.element_type
	end
	return gettypename(typeinfo, v)
end

function reflect.typename(v)
	local typeinfo = reflect.typeof(v)
	return gettypename(typeinfo, v)
end

local can_extand = {
	func = true,
	struct = true,
	union = true,
}

function reflect.canextand(v)
	local typeinfo = reflect.typeof(v)
	if typeinfo.what == 'ptr' or typeinfo.what == 'ref' then
		typeinfo = typeinfo.element_type
	end
	return can_extand[typeinfo.what] or false
end

function reflect.member(v, index)
	local typeinfo = reflect.typeof(v)
	if typeinfo.what == 'ptr' or typeinfo.what == 'ref' then
		typeinfo = typeinfo.element_type
	end
	local reflct = typeinfo:member(index)
	if not reflct then
		return
	end
	return reflct, reflct.name and v[reflct.name]
end

function reflect.annotated_member(typeinfo, index, v)
	local reflct = typeinfo:member(index)
	if not reflct then
		return
	end
	return reflct, reflct.name and v[reflct.name]
end

function reflect.what(v)
	local typeinfo = reflect.typeof(v)
	if typeinfo.what == 'ptr' or typeinfo.what == 'ref' then
		typeinfo = typeinfo.element_type
	end
	return typeinfo and typeinfo.what
end

function reflect.clean()
	ti_cache = {}
	linker_cache = {}
end

return function (funcname, v1, v2, v3)
	return reflect[funcname](v1, v2, v3)
end
