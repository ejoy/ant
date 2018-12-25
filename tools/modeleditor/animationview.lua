local animationview = {}; animationview.__index = animationview
local ctrlutil = require "editor.controls.util"

local inputer = require "tools.modeleditor.fileselectinputer"
local probeclass = require "editor.controls.assetprobe"
local path = require "filesystem.path"

local function create_ani_ctrl(aniview)
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

	local add_blend_btn = iup.button {
		TITLE = "+",
		NAME = "ADD_BLEND",
	}

	local ac = ctrlutil.create_ctrl_wrapper(function ()
		return iup.hbox {
				iup.label {
					TITLE = "ani",
					NAME = "TAG",
					ALIGNMENT="ALEFT",
				},
				inputer.new({NAME="INPUTER"}).view,
				probeclass.new({NAME="PROBE"}).view,
				add_blend_btn,
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

	function add_blend_btn:action()
		local blender = aniview:get_blender()
		if blender then
			local inputer = ac:get_inputer()
			local filename = inputer:get_filename()
			blender:add(filename)
		end
	end

	return ac
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

function animationview:set_blender(blender)
	self.blender = blender
end

function animationview:get_blender()
	return self.blender
end

function animationview:get_sel_ani()
	
end

local function add_child(aniview)
	local view = aniview.view
	local numchild = iup.GetChildCount(view)
					
	local afterchild = iup.GetChild(view, numchild - 1)

	local newctrl = create_ani_ctrl(aniview)
	iup.Insert(view, afterchild, newctrl.view)
	iup.Map(newctrl.view)
	iup.Refresh(view)

	return newctrl
end

local function update_tag_name(aniview, idx)
	local view = aniview.view
	local anictrl = iup.GetChild(view, idx).owner
	local tag = iup.GetChild(anictrl.view, 0)
	assert(tag.NAME == "TAG")
	local inputer = anictrl:get_inputer()	
	local name = path.filename_without_ext(inputer:get_filename())

	name = name or "ani"

	local function chop_name(name)
		if #name > 10 then
			local prefix = name:sub(1, 4)
			local surfix = name:sub(#name-3)
			return prefix .. ".." .. surfix
		end
	end

	tag.TITLE = name ~= "" and chop_name(name) or "ani"
	iup.Refresh(anictrl.view)
end

function animationview:add(filename)
	local child = add_child(self)
	child:get_inputer():set_filename(filename)

	update_tag_name(self, self:count() - 1)
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