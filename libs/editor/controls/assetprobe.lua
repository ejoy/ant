--luacheck: globals iup

local probe = {}; probe.__index = probe


local ctrlutil = require "editor.controls.util"
local observer = require "editor.common.observer"

function probe:add_probe(name, cb)
	self.observers:add("fetch_asset", name, cb)	
end

function probe:injust_assetview(assview)
	self.assetview = assview
end

function probe:remove_assetview()
	self.assetview = nil
end

function probe.new(config)
	local c = ctrlutil.create_ctrl_wrapper(function ()	
		local name = config and config.NAME or "PROBE"
		return iup.button {
			NAME = name,
			TITLE="!",
			action = function (self)
				local owner = assert(self.owner)
				local av = owner.assetview
				if av then
					owner.observers:notify("fetch_asset", av:get_select_res())
				end
			end,
		}
	
	end, probe)

	c.observers = observer.new()
	return c
end

return probe