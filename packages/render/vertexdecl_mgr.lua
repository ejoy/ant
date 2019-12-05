local mgr = {}; mgr.__index = mgr

local bgfx = require "bgfx"

local declmapper = {}

local name_mapper = {
	p = "POSITION",	n = "NORMAL", T = "TANGENT",	b = "BITANGENT",
	i = "INDICES",	w = "WEIGHT",
	c = "COLOR", t = "TEXCOORD",
}

local name_remapper = {
	JOINTS = "i",
	WEIGHTS = "w",
}
for k, v in pairs(name_mapper) do
	name_remapper[v] = k
end

mgr.name_mapper = name_mapper
mgr.name_remapper = name_remapper

function mgr.parse_attri_name(fullname)
	local name, channel = fullname:match("(%w+)_?(%d+)")
	if name then
		return name_remapper[name], channel
	end
	return name_remapper[fullname], 0
end

local function get_attrib(e)
	local a = e:sub(1, 1)
	local attrib = assert(name_mapper[a])
	if attrib == "COLOR" or attrib == "TEXCOORD" then
		local channel = e:sub(3, 3)
		return attrib .. channel
	end

	return attrib
end

local shortname_mapper = {
	u = "UINT8", U = "UINT10", i = "INT16",
	h = "HALF",	f = "FLOAT",
}

local function get_type(v)
	return assert(shortname_mapper[v])
end

local function decl_name(elemname)
	assert(#elemname == 6)
	local attrib 	= get_attrib(elemname)
	local num 		= tonumber(elemname:sub(2, 2))
	local normalize = elemname:sub(4, 4) == "n"
	local asint		= elemname:sub(5, 5) == "i"
	local type 		= get_type(elemname:sub(6, 6))
	return {attrib, num, type, normalize, asint}
end

local function create_decl(vb_layout)
	local decl = {}
	for e in vb_layout:gmatch("%w+") do
		decl[#decl+1] = decl_name(e)
	end

	local d, stride = bgfx.vertex_layout(decl)
	return {handle=d, stride=stride}
end

local default_vbelem = "_30NIf"
function mgr.correct_elem(elem)
	local len = #elem
	return len == #default_vbelem and
			elem or
			elem .. default_vbelem:sub(len+1)
end

function mgr.correct_layout(layout)
	local t = {}
	for e in layout:gmatch("%w+") do
		t[#t+1] = mgr.correct_elem(e)
	end

	return table.concat(t, "|")
end

function mgr.get(layout)
	local decl = declmapper[layout]
	if decl then
		return decl
	end

	local newlayout = mgr.correct_layout(layout)

	decl = declmapper[newlayout]
	if decl == nil then
		decl = create_decl(newlayout)
		declmapper[layout] = decl
	end

	return decl
end

return mgr