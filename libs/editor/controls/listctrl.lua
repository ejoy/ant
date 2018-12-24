--luachecks: globals iup

local lc = {}; lc.__index = lc

local ctrlutil = require "editor.controls.util"

function lc:count()
	return tonumber(self.view.COUNT)
end

function lc:append_item(name, ud)
	local l = self.view
	l.APPENDITEM = name	
	self:set_ud(self:count(), ud)
end

function lc:get_ud(item)
	assert(type(item) == "number")
	return self.ud[item]
end

function lc:set_ud(item, ud)
	if ud then
		self.ud[item] = ud
	end
end

function lc:insert_item(pos, name, ud)
	if pos == nil then
		pos = self:conut()
	end

	self:set_ud(pos, ud)
	assert(pos <= self:count())
	local where = "INSERTITEM" .. pos
	self.view[where] = name
end

function lc:remove(item)
	self.view.REMOVEITEM = item
	table.remove(self.ud, item)
end

function lc:clear()
	self.ud = {}
	self.view.REMOVEITEM = "ALL"
end


function lc.new(config)
	local owner = ctrlutil.create_ctrl_wrapper(function ()
		config = config or {}
		local defaultcfg = {
			--RASTERSIZE = "300x300",
			EXPAND = "YES",
			SCROLLBAR = "YES",
		}
		for k, v in pairs(defaultcfg) do
			config[k] = v
		end
	
		return iup.list(config)
	end, lc)

	owner.ud = {}
	return owner
end
return lc