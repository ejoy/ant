local inputer = {}; inputer.__index = inputer

local ctrlutil = require "editor.controls.util"
local observersclass = require "editor.common.observer"


function inputer:get_text()
	local view = self.view
	return iup.GetChild(view, 0)
end
function inputer:get_filename()
	return self:get_text().VALUE
end

function inputer:set_filename(filename)
	self:get_text().VALUE = filename
end

function inputer:add_changed_cb(cb)
	if self.observers == nil then
		self.observers = observersclass.new()
	end

	self.observers:add(cb)
end

function inputer.new(config)
	return ctrlutil.create_ctrl_wrapper(function()
		return iup.hbox {
			NAME = config and config.NAME or nil,
			EXPAND = "HORIZONTAL",
			iup.text {
				NAME="TEXT",
				ALIGNMENT="ALEFT",
				EXPAND ="ON",
				SIZE="120x0",
				kill_focus_cb = function(self)
					if self.observers then
						self.observers:notify(self.VALUE)
					end
				end,
			},
			iup.button {
				NAME="BROWSE",
				TITLE="...",
				ALIGNMENT="ARIGHT",
				action = function (self)
					local parent = iup.GetParent(self)
					local text = iup.GetChild(parent, 0)
					assert(text.NAME == "TEXT")
					local owner = parent.owner
					local filter = owner.filter
					text.VALUE = iup.GetFile(filter)
					if self.observers then
						self.observers:notify(text.VALUE)
					end
				end,
			},		
		}
	end, inputer)


end

return inputer