local matrixview = {}; matrixview.__index = matrixview

function matrixview:resize(cnum, lnum)
	local view = self.view
	view.NUMCOL = cnum
	view.NUMLIN = lnum
end

function matrixview:getuserdata(col, lin)
	local ud = assert(self.userdata)
	local c = ud[col]
	if c then
		return c[lin]
	end
	return nil
end

function matrixview:setuserdata(col, lin, data)
	local ud = assert(self.userdata)
	local c = ud[col]
	if c == nil then
		c = {}
		ud[col] = c
	end

	c[lin] = data
end

function matrixview:getcell(col, lin)
	return self.view:getcell(col, lin)
end

function matrixview:setcell(col, lin, v)
	self.view:setcell(col, lin, v)
end

local function create_view(config, inst)
	local param = {
		COLNUM = 0, LINNUM = 0
	}
	if config then
		for k, v in pairs(config) do
			param[k] = v
		end
	end

	local view = iup.matrix(param)
	function view:click_cb(col, lin, status)
		local cb = inst.click_cb
		if cb then
			return cb(inst, col, lin, status)
		end
	end

	return view
end

function matrixview.new(config)
	local inst = {
		userdata = {}
	}
	inst.view = create_view(config, inst)
	return setmetatable(inst, matrixview)
end

return matrixview

