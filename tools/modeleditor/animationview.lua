local animationview = {}; animationview.__index = animationview
local ctrlutil = require "editor.controls.util"

local inputer = require "tools.modeleditor.fileselectinputer"
local probeclass = require "editor.controls.assetprobe"

local function create_ani_ctrl()
	local ani_ctrl = {}; ani_ctrl.__index = ani_ctrl
	function ani_ctrl:get_filename()
		return self:get_inputer():get_filename()
	end

	function ani_ctrl:get_inputer()
		local view = self.view
		local inputer = iup.GetChild(view, 1)
		assert(inputer.NAME == "INPUTER")
		return inputer.owner
	end

	return ctrlutil.create_ctrl_wrapper(function ()
		return iup.hbox {
				iup.label {
					TITLE = "ani",
					NAME = "TAG",
					ALIGNMENT="ALEFT",					
				},
				inputer.new({NAME="INPUTER"}).view,
				probeclass.new({NAME="PROBE"}).view,
				iup.button {
					TITLE = "X",
					NAME = "DEL",
					ALIGNMENT="ARIGHT",
					action = function (self)
						local parent = iup.GetParent(self)
						assert(iup.GetClassName(parent) == "hbox")												
						local grandparent = iup.GetParent(parent)

						iup.Detach(parent)
						iup.Destroy(parent)						
						if grandparent then
							iup.Refresh(grandparent)
						end
					end,
				},
				EXPAND = "YES",
			}
		end, ani_ctrl)
end

function animationview:get(idx)
	local view = self.view
	local numchild = self:count()
	assert(idx < numchild)
	local child = iup.GetChild(view, idx)
	return assert(child.owner)
end

function animationview:count()
	local numchild = iup.GetChildCount(self.view)
	assert(numchild >= 1)
	return numchild - 1
end

local function add_child(aniview)
	local view = aniview.view
	local numchild = iup.GetChildCount(view)
					
	local afterchild = iup.GetChild(view, numchild - 1)

	local newctrl = create_ani_ctrl(view)
	iup.Insert(view, afterchild, newctrl.view)
	iup.Map(newctrl.view)
	iup.Refresh(view)

	return newctrl
end

function animationview:add(filename)
	local child = add_child(self)
	child:get_inputer():set_filename(filename)
end

function animationview.new(config)
	return ctrlutil.create_ctrl_wrapper(function ()
		return iup.vbox {
			NAME = config and config.NAME or nil,
			EXPAND = "YES",
			iup.button {
				TITLE = "+",
				EXPAND = "HORIZONTAL",
				action = function (self)
					local vbox = iup.GetParent(self)
					add_child(vbox.owner)
				end
			},				
			
		}
	end, animationview)
end

return animationview