local L = {}

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

L.NAME_MAPPER = NAME_MAPPER

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

function L.elem_size(corrected_elem)
	assert(#corrected_elem == 6)
	local count = tonumber(corrected_elem:sub(2, 2))
	local comp_size = assert(COMPSIZE_MAPPER[corrected_elem:sub(6, 6)])
	return count * comp_size
end

function L.layout_stride(corrected_layout)
	local stride = 0
	for e in corrected_layout:gmatch "%w+" do
		stride = stride + L.elem_size(e)
	end
	return stride
end

local LAYOUT_NAMES = {}

function L.layout_name(elemname)
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

local default_vbelem = "_30NIf"
function L.correct_elem(elem)
	local len = #elem
	return len == #default_vbelem and
			elem or
			elem .. default_vbelem:sub(len+1)
end

function L.correct_layout(layout)
	local t = {}
	for e in layout:gmatch "%w+" do
		t[#t+1] = L.correct_elem(e)
	end

	return table.concat(t, "|")
end

function L.vertex_desc_str(correct_layout)
	local s = ""
	for e in correct_layout:gmatch "%w+" do
		if #e ~= 6 then
			error(("layout should be corrected, use 'correct_layout':%s, %s"):format(e, correct_layout))
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

--layout to inputs/varyings

local SEMANTICS_WITH_INDICES<const> = {
    c = true, t = true
}

local function format_varying(d)
    local n = d:sub(2, 2)
    local w = d:sub(1, 1)
    local s = assert(NAME_MAPPER[w])
    local i = d:sub(3, 3)
    local t = d:sub(6, 6)
    local o = d:sub(4, 4)

    local datatype
    if w == 'i' then
        if o ~= 'N' then
            error(("'INDICES/JOINTS' attribute:%s should not defined as normalize"):format(d))
        end
        if t ~= 'u' and t ~= 'i' then
            error(("Invalid INDICES/JOINTS type:%s, it data element must be 'u'/'i' for uint8 or uint16"):format(d))
        end
        datatype = "ivec"
    else
        datatype = "vec"
        if o ~= 'n' and t ~= 'f' then
            error(("Invalid attribute:%s, not nomalize data should only be 'float'"):format(d))
        end
    end
    return SEMANTICS_WITH_INDICES[w] and ("%s%s %s%s"):format(datatype, n, s, i) or ("%s%s %s"):format(datatype, n, s)
end

local INPUTNAMES<const> = {
    p = "a_position", c = "a_color", n = "a_normal", T = "a_tangent", b = "a_bitangent",
    t = "a_texcoord", i = "a_indices", w = "a_weight",
}

function L.varying_inputs(corrected_layout)
    local varying_inputs = {}
    for dn in corrected_layout:gmatch "%w+" do
        local t = dn:sub(1, 1)
        local vn = SEMANTICS_WITH_INDICES[t] and (INPUTNAMES[t] .. dn:sub(3, 3)) or INPUTNAMES[t]
        varying_inputs[vn] = format_varying(dn)
    end

    return varying_inputs
end

function L.parse_varyings(varyings)
    local t = {}
    for k, v in pairs(varyings) do
        if type(v) == "string" then
            local dd = {}
            for e in v:gmatch "%w+" do
                dd[#dd+1] = e
            end
            t[k] = {
                type = dd[1],
                bind = dd[2],
            }
        else
            assert(v.bind)
            assert(v.type)
            t[k] = v
        end
    end

    return t
end

L.SEMANTICS_WITH_INDICES = SEMANTICS_WITH_INDICES

return L