local ecs = ...

local bgfx = require "bgfx"
local fs = require "filesystem"
local datalist = require "datalist"
local assetmgr = require "asset"

local m = ecs.component "material"

local function load_state(filename)
	if type(filename) == "string" then
		local f = assert(fs.open(fs.path(filename), 'rb'))
		local data = f:read 'a'
		f:close()
		return datalist.parse(data)
	else
		return filename
	end
end

function m:init()
	self.fx = assetmgr.load_fx(self.fx)
	if #self.fx.uniforms > 0 and not self.properties then
		self.properties = {}
	end
	self._state = bgfx.make_state(load_state(self.state))
	return self
end
