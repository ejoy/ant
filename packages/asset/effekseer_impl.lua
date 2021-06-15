local ecs = ...
local assetmgr = require "asset"
local effekseer = require "effekseer"

local m = ecs.component "effekseer"

function m:init()
	if type(self) == "string" then
		local res = assetmgr.resource(self)
		return {
			rawdata 	= res.rawdata,
			filedir 	= res.filedir,
			speed 		= 1.0,
			auto_play 	= true,
			loop 		= true
		}
	end
	return self
end

function m:delete()
	-- if self.handle then
	-- 	effekseer.destroy(self.handle)
	-- end
end