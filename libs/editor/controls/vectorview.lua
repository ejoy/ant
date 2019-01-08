local vectorview = {}; vectorview.__index = {}

local ctrlutil = require "editor.controls.util"

local function ctrl_value(owner, idx, name, value)
	local view = owner.view
	local containter = iup.GetChild(view, 1)
	local C = iup.GetChild(containter, idx)
	assert(C.NAME == name)
	if value == nil then
		return tonumber(C.TITLE)
	else
		C.TITLE = tostring(value)
	end	
end

function vectorview:x(v)
	ctrl_value(self, 1, "X", v)
end

function vectorview:y(v)
	ctrl_value(self, 3, "Y", v)
end

function vectorview:z(v)
	ctrl_value(self, 5, "Z", v)
end

function vectorview:get_vec()
	return {self:x(), self:y(), self:z()}
end


function vectorview.new(config)
	return ctrlutil.create_ctrl_wrapper(function ()
		return iup.frame {
			NAME = config.NAME,			
			TITLE = config.TITLE,
			iup.hbox {				
				iup.label {TITLE="x:"},
				iup.text {NAME="X", MINSIZE="32x"},
				iup.label {TITLE="y:"},
				iup.text {NAME="Y", MINSIZE="32x"},
				iup.label {TITLE="z:"},
				iup.text {NAME="Z", MINSIZE="32x"},
			}
		}
	end, vectorview)
end


return vectorview