local animationview = {}; animationview.__index = animationview
local ctrlutil = require "editor.controls.util"

local probeclass = require "editor.controls.assetprobe"
local fs = require "filesystem"
local matviewclass = require "editor.controls.matrixview"

local function get_gird(aniview)
	local view = aniview.view
	local gird = iup.GetChild(view, 1).owner
	assert(gird.view.NAME == "ANILIST")
	return gird
end

function animationview:get(idx)
	local gird = get_gird(self)
	local lineidx = idx or gird:focus()
	return gird:getcell(lineidx, 2)
end

function animationview:count()
	local gird = get_gird(self)
	local ln = gird:size()
	return ln
end

function animationview:set_blender(blender)
	self.blender = blender
end

function animationview:get_blender()
	return self.blender
end

local function get_tag_name(filename)
	local name = filename:filename():string():match("([^.]+)")
	name = name or "ani"

	local function chop_name(name)
		if #name > 10 then
			local prefix = name:sub(1, 4)
			local surfix = name:sub(#name-3)
			return prefix .. ".." .. surfix
		end
	end

	return name ~= "" and chop_name(name) or "ani"	
end

local function add_ani_to_gird(gird, filepath)
	gird:append_line({get_tag_name(filepath), filepath:string()})
	gird:fit_col_content_size(2)
end

local function get_probe(aniview)
	local view = aniview.view
	local container = iup.GetChild(view, 0)
	return assert(iup.GetChild(container, 0).owner)	
	
end

function animationview:add(filepath)
	add_ani_to_gird(get_gird(self), filepath)
end

function animationview:injust_assetview(av)
	self.assetview = av

	local probe = get_probe(self)
	probe:injust_assetview(av)
end

function animationview.new(config)
	local toblend_btn = iup.button {
		TITLE=">>",
		NAME = "TOBLEND",
	}

	local aniview = ctrlutil.create_ctrl_wrapper(function ()
		local gird = matviewclass.new {NAME="ANILIST"}
		gird:setcell(0, 1, "Name")
		gird:setcell(0, 2, "FullPath")

		local probe = probeclass.new()
		probe:add_probe("aniview", function (filepath)
			add_ani_to_gird(gird, filepath)
		end)

		return iup.vbox {
			NAME = config and config.NAME or nil,
			iup.hbox {
				probe.view,
				toblend_btn,
				iup.button {
					TITLE="X",
					ALIGNMENT = "ARIGHT",
					NAME = "DELRES",
					action = function (self)
						local ln = gird:focus()
						gird:remove_line(ln)
					end,
				},
			},
			gird.view,
		}
	end, animationview)

	function toblend_btn:action()
		local blender = aniview:get_blender()
		if blender then
			local gird = get_gird(aniview)
			local ln = gird:focus()			
			blender:add(fs.path(gird:getcell(ln, 2)))
		end
	end

	return aniview
end

return animationview