local probe = {}; probe.__index = probe

function probe:notify(respath)
	local observers = self.observers
	if observers then
		for _, ob in ipairs(observers) do
			ob.cb(respath)
		end
	end	
end

function probe:add_probe(name, cb)
	local observers = self.observers
	if observers == nil then
		observers = {}
		self.observers = observers
	end

	table.insert(observers, {name=name, cb=cb})
end

function probe.new(config)
	local function create(config)
		local view = iup.button {
			TITLE="!"
		}

		function view:action()
			local dlg = iup.GetDialog(self)
			local assetview = iup.GetDialogChild(dlg, "ASSETVIEW")
			if assetview then
				local avowner = assetview.owner
				local respath = avowner:get_select_res()
				local owner = self.owner
				if owner then
					owner:notify(respath)
				end
			end
		end
		return {view=view}
	end

	local btn = create(config)
	btn.view.owner = btn
	return setmetatable(btn, probe)
end

return probe