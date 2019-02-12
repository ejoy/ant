local animationview = {}; animationview.__index = animationview

local iupcontrols = import_package "ant.iupcontrols"
local ctrlutil = iupcontrols.util
local probeclass = iupcontrols.assetprobe
local matviewclass = iupcontrols.matrixview

local fs = require "filesystem"


local function get_grid(aniview)
	local view = aniview.view
	local grid = iup.GetChild(view, 1).owner
	assert(grid.view.NAME == "ANILIST")
	return grid
end

function animationview:get(idx)
	local grid = get_grid(self)
	local lineidx = idx or grid:focus()
	return grid:getcell(lineidx, 2)
end

function animationview:count()
	local grid = get_grid(self)
	local ln = grid:size()
	return ln
end

function animationview:set_blender(blender)
	self.blender = blender
end

function animationview:get_blender()
	return self.blender
end

local function get_tag_name(filename)
	local name = filename:match(".+/([^.]+)")
	name = name or "ani"

	local function chop_name(name)
		if #name > 10 then
			local prefix = name:sub(1, 4)
			local surfix = name:sub(#name-3)
			return prefix .. ".." .. surfix
		end
		return name
	end

	return name ~= "" and chop_name(name) or "ani"	
end

local function add_ani_to_grid(grid, filepath)
	grid:append_line({get_tag_name(filepath), filepath})
	grid:fit_col_content_size(2)
end

local function get_probe(aniview)
	local view = aniview.view
	local container = iup.GetChild(view, 0)
	return assert(iup.GetChild(container, 0).owner)	
	
end

function animationview:add(filepath)
	add_ani_to_grid(get_grid(self), filepath)
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
		local grid = matviewclass.new {NAME="ANILIST"}
		grid:setcell(0, 1, "Name")
		grid:setcell(0, 2, "FullPath")

		local probe = probeclass.new()
		probe:add_probe("aniview", function (filepath)
			add_ani_to_grid(grid, filepath)
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
						local ln = grid:focus()
						grid:remove_line(ln)
					end,
				},
			},
			grid.view,
		}
	end, animationview)

	function toblend_btn:action()
		local blender = aniview:get_blender()
		if blender then
			local grid = get_grid(aniview)
			local ln = grid:focus()			
			blender:add(fs.path(grid:getcell(ln, 2)))
		end
	end

	return aniview
end

return animationview