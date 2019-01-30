local blender = {}; blender.__index = blender

local iupcontrols = import_package "ani.iupcontrols"
local ctrlutil = iupcontrols.util
local observerclass = iupcontrols.common.observer

local blendctrl = {}; blendctrl.__index = blendctrl

function blendctrl:set_filename(filename)
	local text = iup.GetChild(self.view, 1)
	assert(text.NAME == "ANIFILE")
	text.TITLE = filename
end

function blendctrl:get_filename()
	local text = iup.GetChild(self.view, 1)
	assert(text.NAME == "ANIFILE")
	return text.TITLE
end

function blendctrl:set_weight(w)
	local weight = iup.GetChild(self.view, 0)
	assert(weight.NAME == "WEIGHT")
	weight.VALUE = string.format("%2f", w)
end

function blendctrl:get_weight()
	local weight = iup.GetChild(self.view, 0)
	assert(weight.NAME == "WEIGHT")

	return tonumber(weight.VALUE)
end

function blendctrl.new(config)
	return ctrlutil.create_ctrl_wrapper(function ()
		return iup.hbox {
			iup.text {
				TITLE = "0",				
				NAME = "WEIGHT",
			},
			iup.label {
				NAME = "ANIFILE",				
			},
			iup.button {
				TITLE = "X",
				NAME = "DEL",
				action = function (self)
					local parent = iup.GetParent(self)
					local grandpa = iup.GetParent(parent)
					iup.Destroy(parent)
					if grandpa then
						iup.Refresh(grandpa)
					end
				end,
			},
			EXPAND = "NO",
		}
	end, blendctrl)
end

local function get_blendlist_ctrl(bl)
	local blist = iup.GetChild(bl.view, 1)
	assert(blist.NAME == "BLENDERLIST")
	assert(iup.GetClassName(blist) == "vbox")
	return blist
end

function blender:add(filepath, weight)
	weight = weight or 0
	local bc = blendctrl.new()
	bc:set_filename(filepath:string())
	bc:set_weight(weight)
	local blist = get_blendlist_ctrl(self)

	iup.Append(blist, bc.view)
	iup.Map(bc.view)
	iup.Refresh(blist)
end

function blender:count()
	local blist = get_blendlist_ctrl(self)
	return iup.GetChildCount(blist)
end

local function blend_list(bl)
	local blist = get_blendlist_ctrl(bl)
	local count = iup.GetChildCount(blist)

	local list = {}
	for ib=0, count - 1 do
		local bc = assert(iup.GetChild(blist, ib).owner)
		table.insert(list, {filename=bc:get_filename(), weight=bc:get_weight()})
	end
	return list
end

function blender:blend(type)
	local observers = self.observers
	if observers then
		local list = blend_list(self)
		observers:notify("blend", list, type)
	end
end

function blender:observer_blend(name, cb)
	if self.observers == nil then
		self.observers = observerclass.new()
	end
	self.observers:add("blend", name, cb)
end

function blender.new(config)
	local applybtn = iup.button {
		TITLE = "Apply",
	}

	local blendtype = iup.list {
		DROPDOWN="YES",
		VALUESTRING  = "Blend",
		"Additive",
		"Attach",
		"Blend",
	}

	local bl = ctrlutil.create_ctrl_wrapper(function ()
		return iup.vbox {
			NAME = "BLENDER",
			iup.hbox {
				blendtype,
				applybtn,
			},
			iup.vbox {
				NAME = "BLENDERLIST",
			},
			EXPAND = "NO",
		}
	end, blender)

	function applybtn:action()
		bl:blend(blendtype.VALUESTRING)
	end

	return bl
end

return blender