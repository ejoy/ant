local animationview = {}; animationview.__index = animationview
local ctrlutil = require "editor.controls.util"

local inputer = require "tools.modeleditor.fileselectinputer"
local probeclass = require "editor.controls.assetprobe"
local path = require "filesystem.path"

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
	local name = path.filename_without_ext(filename)
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

local function add_ani(aniview, filename)
	local gird = get_gird(aniview)
	
	gird:append_line({get_tag_name(filename), filename})
end

function animationview:add(filename)
	add_ani(self, filename)
end

function animationview.new(config)
	return ctrlutil.create_ctrl_wrapper(function ()
		local gird = matviewclass.new {NAME="ANILIST"}
		gird:setcell(0, 1, "Name")
		gird:setcell(0, 2, "FullPath")

		local probe = probeclass.new()
		probe:add_probe("aniview", add_ani)

		return iup.vbox {
			NAME = config and config.NAME or nil,
			iup.hbox {
				probe.view,
				iup.button {
					TITLE="X",
					action = function (self)						
						local gird = get_gird(av)
						local ln = gird:focus()
						gird:remove_line(ln)
					end,
				}
			},
			gird.view,
		}
	end, animationview)
end

return animationview