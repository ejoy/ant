local menu = {}; menu.__index = menu

function menu:show(x, y)
	self.m:popup(x, y)
end

local function create_menu(config)
	local recipe = config.recipe
	local items = {}

	for _, item in ipairs(recipe) do
		local mi = iup.item {
			title = item.name
		}
		mi.action = item.action
		table.insert(items, mi)
	end

	items.open_cb 		= config.open_cb
	items.menuclose_cb 	= config.menuclose_cb

	return iup.menu(items)
end

function menu.new(config)
	return setmetatable({m=create_menu(config)}, 
		menu)
end

return menu