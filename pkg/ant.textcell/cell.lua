local core = require "cell.core"

local cell = {}

local objcache = setmetatable({}, {__mode = "kv"})
local context = {}

local function getself()
	return context[context.current].cell
end

function cell.color(color)
	if context.current == nil then
		context.color = color
	else
		local self = getself()
		core.color(self._c, color)
	end
end

function cell.row(height)
	local self = getself()
	core.rowset(self._c, height)
end

function cell.nextrow()
	local self = getself()
	core.nextrow(self._c)
end

function cell.col(idx)
	local self = getself()
	core.col(self._c, idx)
end

function cell.text(t)
	local self = getself()
	local s = self._text
	local id = #s + 1
	s[id] = t
	core.insert(self._c, id)
end

local function cell_inner(self, id, obj)
	self._text[-id] = obj
	return core.insert(self._c, -id)
end

local function cell_new()
	local o = {
		_c = core.new(),
	}

	return setmetatable(o, meta)
end

function cell.open(fmt)
	local self = next(objcache)
	if not self then
		self = cell_new()
	end

	local id = #context + 1
	self._text = {}
	self._fmt = fmt
	core.clear(self._c)
	local obj = {
		cell = self,
	}
	local cur = context.current
	if cur then
		obj.parent = cur
		obj.x , obj.y = cell_inner(context[cur].cell, id, self._c)
	end
	context[id] = obj
	context.current = id
	if context.color then
		core.color(self._c, context.color)
	end
	return self
end

function cell.close()
	context.current = context[context.current].parent
end

local alignment = {
	["<"] = -1,
	[">"] = 1,
	["="] = 0,
	[""] = -1,
}

local function format_cols(fmt)
	local f = ""
	for a, w, percent in fmt:gmatch "([<>=]?)(%d+)(%%?)" do
		a = alignment[a]
		local n = tonumber(w)
		if percent == "%" then
			n = -n
		end
		f = f .. (string.pack("ii", a, n))
	end
	return f
end

local format_cache = {}
setmetatable(format_cache, {
	__index = function (c, key)
		local u = format_cols(key)
		c[key] = u
		return u
	end
})

local function calc_layout(id)
	local obj = context[id]
	if obj.width then
		return
	end
	local parent = context[obj.parent]
	if parent then
		if parent.width == nil then
			calc_layout(obj.parent)
		end
		width = core.colwidth(parent.cell._c, obj.x)
	else
		width = context.width
	end
	local u = format_cache[obj.cell._fmt or ""]
	obj.width = core.setlayout(obj.cell._c, u, width)
	context.order[context.n] = id
	context.n = context.n - 1
end

function cell.frame(w, h)
	context.width = w
	context.order = {}
	context.n = #context
	for idx in ipairs(context) do
		calc_layout(idx)
	end
	for _, id in ipairs(context.order) do
		local obj = context[id]
		local cell = obj.cell
		core.format(cell._c, cell._text, obj.width, h)
		objcache[cell] = true
	end
	local root = context[1].cell
	context = {}
	return core.image(root._c)
end

cell.tostring = core.tostring

return cell