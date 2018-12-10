--luacheck: globals iup
local link = {}; link.__index = link

local path = require "filesystem.path"

function link.new(config, name, url)
	local function create(config)
		local lk = iup.link {
			URL=url,
			TITLE=name,
		}

		return {view=lk}
	end

	local lk = create(config)
	lk.view.owner = lk	

	function lk.view:action(url)
		local addr = iup.GetParent(self)
		local owner = assert(addr.owner)
		owner:update(url)
	end

	return lk
end

local addressnavigation = {}; addressnavigation.__index = addressnavigation

function addressnavigation:push(name, url)	
	local lk = link.new(nil, name, url)

	local view = self.view
	local childcount = iup.GetChildCount(view)
	if childcount > 0 then
		local label = iup.label {
			TITLE=">"
		}
		
		iup.Append(view, label)		
		iup.Map(label)
	end

	iup.Append(view, lk.view)	
	iup.Map(lk.view)
end

function addressnavigation:clear()
	local view = self.view
	local childcount = iup.GetChildCount(view)
	if childcount == 0 then
		return
	end

	local children = {}
	for idx=1, childcount do
		local cih = iup.GetChild(view, idx-1)				
		table.insert(children, cih)
	end

	for _, c in ipairs(children) do
		iup.Detach(c)
	end
	iup.Refresh(view)
end

local function split_url(url)
	local names = {}
	repeat
		local name = path.filename(url)
		table.insert(names, 1, {name, url})
		url = path.parent(url)
	until url == nil
	return names
end

function addressnavigation:update(url)
	-- TODO: we can only detach different names on address with url
	local names = split_url(url)
	self:clear()

	for _, name in ipairs(names) do
		self:push(name[1], name[2])
	end

	iup.Refresh(self.view)

	local observers = self.observers
	if observers then
		for _, observer in ipairs(observers) do
			observer.cb(url)
		end
	end
end

function addressnavigation:add_click_address_cb(name, cb)
	local observers = self.observers
	if observers == nil then		
		observers = {}
		self.observers = observers
	end

	table.insert(observers, {name=name, cb=cb})
end


local function create(config)
	local addr = iup.hbox {
		NAME="ADDR_NAG",
		EXPAND="ON",
	}

	return {view=addr}
end

function addressnavigation.new(config)
	local an = create(config)
	an.view.owner = an
	return setmetatable(an, addressnavigation)
end

return addressnavigation