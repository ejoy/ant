--luachecks: globals iup

local lc = {}; lc.__index = lc

function lc:append_item(name, ud)
	local l = self.list
	l.APPENDITEM = name
	table.insert(self.ud, ud)

	assert(#self.ud == tonumber(l.COUNT))
end

function lc:get_ud(item)
	assert(type(item) == "number")
	return self.ud[item]
end

function lc:remove(item)
	self.list.REMOVEITEM = item
	table.remove(self.ud, item)
end

function lc:clear()
	self.ud = {}
	self.list.REMOVEITEM = "ALL"
end

local function create(config)
	config = config or {}
	local defaultcfg = {
		--RASTERSIZE = "300x300",
		EXPAND = "YES",
		SCROLLBAR = "YES",
	}
	for k, v in pairs(defaultcfg) do
		config[k] = v
	end

	return {list=iup.list(config), ud={}}
end

function lc.new(config)
	local l = setmetatable(create(config), lc)
	l.list.owner = l
	return l
end
return lc