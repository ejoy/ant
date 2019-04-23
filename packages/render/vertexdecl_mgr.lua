local mgr = {}; mgr.__index = mgr

local bgfx = require "bgfx"

local declmapper = {}

local function get_attrib(e)
	local t = {	
		p = "POSITION",	n = "NORMAL", T = "TANGENT",	b = "BITANGENT",
		i = "INDICES",	w = "WEIGHT",
		c = "COLOR", t = "TEXCOORD",
	}
	local a = e:sub(1, 1)
	local attrib = assert(t[a])
	if attrib == "COLOR" or attrib == "TEXCOORD" then
		local channel = e:sub(3, 3)
		return attrib .. channel
	end

	return attrib
end

local function get_type(v)					
	local t = {	
		u = "UINT8", U = "UINT10", i = "INT16",
		h = "HALF",	f = "FLOAT",
	}
	return assert(t[v])
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

	local decl, stride = bgfx.vertex_decl(decl)
	return {handle=decl, stride=stride}
end

local default_vbelem = "_30NIf"
local function correct_elem(elem)
	local len = #elem
	return len == #default_vbelem and 
			elem or 
			elem .. default_vbelem:sub(len+1)
end

local function correct_layout(layout)
	local t = {}	
	for e in layout:gmatch("%w+") do
		t[#t+1] = correct_elem(e)
	end

	return table.concat(t, "|")
end

function mgr.get(layout)	
	local decl = declmapper[layout]	
	if decl then
		return decl
	end

	local newlayout = correct_layout(layout)

	decl = declmapper[newlayout]
	if decl == nil then
		decl = create_decl(layout)
		declmapper[layout] = decl
	end

	return decl
end

function mgr.decl_str(layout)
	local s = ""
	for e in layout:gmatch("%w+") do
		local ce = correct_elem(e)
		local num 		= tonumber(ce:sub(2, 2))
		local asint		= ce:sub(5, 5) == "i"
		local n = asint and "i" or "f"
		for i=1, num do
			s = s .. n
		end
	end

	return s
end

return mgr