--luacheck: globals iup
local link = {}; link.__index = link
local fs = require "filesystem"
local observersclass = require "common.observer"
local ctrlutil = require "controls.util"

function link.new(config, name, url)
	return ctrlutil.create_ctrl_wrapper(function ()
		return iup.link {
			URL=url:string(),
			TITLE=name:string(),
			action = function(self, url)
				-- should use injust
				local addr = iup.GetParent(self)
				local owner = assert(addr.owner)
				local urlpath = fs.path(url)
				owner:update(urlpath)
				owner:notify(urlpath)
			end
		}
	end, link)
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
		iup.Destroy(c)
	end
	iup.Refresh(view)
end

local function split_url(url)
	local names = {}
	repeat
		local name = url:filename()
		table.insert(names, 1, {name, url})
		url = url:parent_path()
		local urlstr = url:string()
	until urlstr == "" or urlstr == "/"
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
end

function addressnavigation:notify(url)
	local observers = self.observers
	if observers then
		observers:notify("click", url)
	end
end

function addressnavigation:add_click_address_cb(name, cb)
	if self.observers == nil then
		self.observers = observersclass.new()
	end
	
	self.observers:add("click", name, cb)
end


function addressnavigation.new(config)
	return ctrlutil.create_ctrl_wrapper(function ()
		return iup.hbox {
			NAME = config and config.name or "ADDR_NAG",
			EXPAND = "YES",
		}
	end, addressnavigation)
end

return addressnavigation