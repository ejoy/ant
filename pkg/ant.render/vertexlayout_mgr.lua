local mgr = {}

local NAME_MAPPER<const> = {
	p = "POSITION", 	POSITION = "p",
	n = "NORMAL",		NORMAL = "n",
	T = "TANGENT",		TANGENT = "T",
	b = "BITANGENT",	BITANGENT = "b",
	c = "COLOR",		COLOR = "c",
	t = "TEXCOORD",		TEXCOORD = "t",
	
	i = "INDICES",		INDICES = "i",	JOINTS = "i",
	w = "WEIGHT",		WEIGHT = "w",	WEIGHTS = "w",
}

mgr.NAME_MAPPER = NAME_MAPPER

function mgr.parse_attri_name(fullname)
	local name, channel = fullname:match("(%w+)_?(%d+)")
	if name then
		return NAME_MAPPER[name], channel
	end
	return NAME_MAPPER[fullname], 0
end

local function get_attrib(e)
	local a = e:sub(1, 1)
	local attrib = assert(NAME_MAPPER[a])
	if attrib == "COLOR" or attrib == "TEXCOORD" then
		local channel = e:sub(3, 3)
		return attrib .. channel
	end

	return attrib
end

local SHORTNAME_MAPPER<const> = {
	u = "UINT8", U = "UINT10", i = "INT16",
	h = "HALF",	f = "FLOAT",
}

local COMPSIZE_MAPPER<const> = {
	f=4, i=2, u=1,	-- not valid for U, for 10 bit elemenet
}

function mgr.elem_size(corrected_elem)
	assert(#corrected_elem == 6)
	local count = tonumber(corrected_elem:sub(2, 2))
	local comp_size = assert(COMPSIZE_MAPPER[corrected_elem:sub(6, 6)])
	return count * comp_size
end

function mgr.layout_stride(corrected_layout)
	local stride = 0
	for e in corrected_layout:gmatch "%w+" do
		stride = stride + mgr.elem_size(e)
	end
	return stride
end

local LAYOUT_NAMES = {}

local function layout_name(elemname)
	local ln = LAYOUT_NAMES[elemname]
	if ln == nil then
		assert(#elemname == 6)
		local attrib 	= get_attrib(elemname)
		local num 		= tonumber(elemname:sub(2, 2))
		local normalize = elemname:sub(4, 4) == "n"
		local asint		= elemname:sub(5, 5) == "i"
		local type 		= assert(SHORTNAME_MAPPER[elemname:sub(6, 6)])
		ln = {attrib, num, type, normalize, asint}
		LAYOUT_NAMES[elemname] = ln
	end

	return ln
end

local function create_layout(vb_layout)
	local layoutnames = {}
	for e in vb_layout:gmatch("%w+") do
		layoutnames[#layoutnames+1] = layout_name(e)
	end

	local bgfx = require "bgfx"
	local d, stride = bgfx.vertex_layout(layoutnames)
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
	for e in layout:gmatch "%w+" do
		t[#t+1] = mgr.correct_elem(e)
	end

	return table.concat(t, "|")
end

function mgr.vertex_desc_str(correct_layout)
	local s = ""
	for e in correct_layout:gmatch "%w+" do
		if #e ~= 6 then
			error(("layout should be corrected, use declmgr.correct_layout:%s, %s"):format(e, correct_layout))
		end
		local n = e:sub(2, 2)
		local t = e:sub(6, 6)

		if t == 'f' then
			s = s .. ('f'):rep(n)
		elseif t == 'u' then
			if n ~= '4' then
				error(("invalid attribute number for 'u' type, must be 4: %d"):format(n))
			end

			s = s .. "d"
		elseif t == 'i' then
			s = s .. "w"
		end
	end

	return s
end

local LAYOUTS = {}

function mgr.get(layout)
	local l = LAYOUTS[layout]
	if l == nil then
		local newlayout = mgr.correct_layout(layout)

		l = LAYOUTS[newlayout]
		if l == nil then
			l = create_layout(newlayout)
			LAYOUTS[layout]		= l
			LAYOUTS[newlayout]	= l
		end
	end
	return l
end

return mgr