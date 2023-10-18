local plist = {}

function plist.array(array)
	return {
		__type = "array",
		table.unpack(array),
	}
end

local tostring_meta = {
	__tostring = function(v)
		return v.__value
	end
}

function plist.data(data)
	return setmetatable({
		__type = "data",
		__value = tostring(data),
	}, tostring_meta)
end

function plist.date(date)
	local v
	if date == nil then
		-- current date
		v = os.date("!%Y-%m-%dT%H:%M:%SZ")
	elseif type(date) == "string" then
		v = date
	else
		assert(date.__type == "date" )
		v = date.__value
	end

	return setmetatable({
		__type = "date",
		__value = v,
	}, tostring_meta)
end

function plist.dict(dict)
	local ret = {}
	for k,v in pairs(dict) do
		assert(type(k) == "string")
		ret[k] = v
	end
	return ret
end

function plist.type(object)
	local t = type(object)
	if t == "table" then
		local otype = object.__type
		if otype then
			return otype
		else
			return "dict"
		end
	elseif t == "boolean" or t == "string" then
		return t
	else
		local ntype = math.type(object)
		if ntype == "integer" then
			return ntype
		elseif ntype == "float" then
			return "real"
		else
			-- Invalid type
			return nil
		end
	end
end

local toxml = {}

function toxml.integer(v, indent)
	return string.format("%s<integer>%d</integer>", indent, v)
end

function toxml.real(v, indent)
	return string.format("%s<real>%g</real>", indent, v)
end

function toxml.boolean(v, indent)
	if v then
		return indent .. "<true/>"
	else
		return indent .. "<false/>"
	end
end

function toxml.date(v, indent)
	return string.format("%s<date>%s</date>", indent, v)
end

local escape_tbl = setmetatable({
	['&amp;'] = '&',
	['&quot;'] = '"',
	['&apos;'] = "'",
	['&lt;'] = '<',
	['&gt;'] = '>',
}, { __index = function(_,k)
		print("ESCAPE", k)
		local dec = k:match "&#(%d+);"
		if dec then
			return utf8.char(dec)
		else
			local hex = k:match "&#x([%da-fA-F]+);"
			return utf8.char("0x"..hex)
		end
	end })

do
	local keys = {}
	for k,v in pairs(escape_tbl) do
		keys[v] = k
	end
	for k,v in pairs(keys) do
		escape_tbl[k] = v
	end
	for i = 0, 31 do
		escape_tbl[string.char(i)] = "&#"..i..";"
	end
end

local function unescape_string(str)
	str = str:gsub("(&[^;]+;)", escape_tbl)
	return str
end

local function escape_string(str)
	return str:gsub('[<>&"\0-\31]', escape_tbl )
end

function toxml.string(v, indent)
	return string.format("%s<string>%s</string>", indent, escape_string(v))
end

function toxml.data(v, indent)
	local base64 = require "base64"
	local b64 = base64.encode(tostring(v))
	local tmp = { indent , "<data>\n" }
	local data_indent = indent .. "  "
	for i = 1, #b64, 76 do
		local idx = #tmp + 1
		tmp[idx] = data_indent
		tmp[idx+1] = b64:sub(i,i+75)
		tmp[idx+2] = "\n"
	end
	tmp[#tmp + 1] = indent .. "</data>"
	return table.concat(tmp)
end

function toxml.array(array, indent)
	local tmp = { indent .. "<array>" }
	local item_indent = indent .. "  "
	for _, v in ipairs(array) do
		local t = assert(plist.type(v))
		tmp[#tmp+1] = toxml[t](v, item_indent)
	end
	tmp[#tmp+1] = indent .. "</array>"
	return table.concat(tmp, "\n")
end

function toxml.dict(dict, indent)
	local tmp = { indent .. "<dict>" }
	local item_indent = indent .. "  "
	for k, v in pairs(dict) do
		assert(type(k) == "string")
		tmp[#tmp+1] = string.format("%s<key>%s</key>", item_indent, escape_string(k))
		local vtype = assert(plist.type(v))
		tmp[#tmp+1] = toxml[vtype](v, item_indent)
	end
	tmp[#tmp+1] = indent .. "</dict>"
	return table.concat(tmp, "\n")
end

function plist.toxml(object)
	local tmp = {
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
		'<plist version="1.0">',
	}
	local t = assert(plist.type(object))
	tmp[#tmp+1] = toxml[t](object, "")
	tmp[#tmp+1] = "</plist>"
	return table.concat(tmp, "\n")
end

-- parse xml

local function parse_xml(s)
	local stack = {}
	local top = {}
	table.insert(stack, top)
	local ni,c,label,empty
	local i, j = 1, 1
	while true do
		ni,j,c,label,empty = string.find(s, "<([%/?!]?)([%w-=%[]+).-(%/?)>", i)
		if not ni then break end
		local text = string.sub(s, i, ni-1)
		if not string.find(text, "^%s*$") then
			table.insert(top, text)
		end
		if empty == "/" then  -- empty element tag
			table.insert(top, { label=label, empty= true } )
		elseif c == "" then   -- start tag
			top = { label=label }
			table.insert(stack, top)   -- new level
		elseif c == "/" then  -- end tag
			local toclose = table.remove(stack)  -- remove top
			top = stack[#stack]
			if #stack < 1 then
				error("nothing to close with "..label)
			end
			if toclose.label ~= label then
				error("trying to close "..toclose.label.." with "..label)
			end
			table.insert(top, toclose)
		elseif c == "!" then
			if label:match "^%[CDATA%[" then
				if string.sub(s, j-2, j) ~= "]]>" then
					ni,j = string.find(s, "]]>", j+1, true)
					if not ni then
						error("trying to close CDATA")
					end
				end
			end
		end
		-- ignore ?
		i = j+1
	end
	local text = string.sub(s, i)
	if not string.find(text, "^%s*$") then
		table.insert(stack[#stack], text)
	end
	if #stack > 1 then
		error("unclosed "..stack[#stack].label)
	end
	return stack[1]
end

local fromxml = {}

local function from_xml(node)
	local f = fromxml[node.label]
	if not f then
		error("Can't parse label " .. tostring(node.label))
	end
	return f(node)
end

function fromxml.dict(node)
	local object = {}
	for i=1, #node, 2 do
		local key = node[i]
		local value = node[i+1]
		assert(key.label == "key")
		local key = key[1] or ""
		object[unescape_string(key)] = from_xml(value)
	end
	return plist.dict(object)
end

function fromxml.array(node)
	local array = {}
	for k,v in ipairs(node) do
		array[k] = from_xml(v)
	end
	return plist.array(array)
end

function fromxml.integer(node)
	return assert(math.tointeger(node[1]), "Invalid Integer")
end

function fromxml.real(node)
	return tonumber(node[1])
end

function fromxml.date(node)
	return plist.date(node[1])
end

function fromxml.data(node)
	local str = node[1]
	if str == nil then
		return plist.data ""
	end
	local base64 = require "base64"
	local text = str:gsub("%s","")
	local data = base64.decode(text)
	return plist.data(data)
end

fromxml["true"] = function(node)
	return true
end

fromxml["false"] = function(node)
	return false
end

function fromxml.string(node)
	local str = node[1]
	if not str then
		return ""
	else
		return unescape_string(str)
	end
end

function plist.fromxml(xml)
	local node = parse_xml(xml)[1]
	assert(node.label == "plist")
	return from_xml(node[1])
end

------------

return plist
