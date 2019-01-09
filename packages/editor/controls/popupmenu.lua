local menu = {}; menu.__index = menu

function menu:show(x, y)
	self.m:popup(x, y)
end

local function create_menu(config)
	local recipe = config.recipe
	
	local type_ops = {}
	local function build_menu(recipe)
		local items = {}
		for _, item in ipairs(recipe) do
			local op = assert(type_ops[item.type])
			table.insert(items, op(item))
		end

		return items
	end

	type_ops.submenu = function(recipe)
		local sitems = build_menu(recipe)
		return iup.submenu { iup.menu(sitems), title = recipe.name}
	end
	type_ops.separator = function () return iup.separator {} end
	type_ops.item = function (item) return iup.item {title=item.name, action=item.action, active=item.active} end

	local items = build_menu(recipe)

	items.open_cb 		= config.open_cb
	items.menuclose_cb 	= config.menuclose_cb

	return iup.menu(items)
end

function menu.new(config)
	return setmetatable({m=create_menu(config)}, 
		menu)
end

return menu