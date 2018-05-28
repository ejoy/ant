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

function matrixview:setcolwidth(col, size)
	self.view["RASTERWIDTH" .. col] = size
end

function matrixview:setlinwith(lin, size)
	self.view["RASTERHEIGHT" .. lin] = size
end

function matrixview:fit_col_content_size(col, gap)
	gap = gap or 0

	local view = self.view
	local sizew = {}
	local numlin = view["NUMLIN"]
	local cellsize = view["CELLSIZE1:1"]
	print(cellsize)
	for i=0, numlin do
		local c = view:getcell(i, col)
		--local w, h = iup.DrawGetTextSize(c)
		if c then
			local w = iup.DrawGetTextSize(view, c)
			table.insert(sizew, w)		
		end
	end

	if next(sizew) then
		local rw = math.max(table.unpack(sizew))
		self:setcolwidth(col, rw + gap)
	end
end

function matrixview:shrink(linnum, colnum)
	local view = self.view	
	if colnum then
		local cn = tonumber(view["NUMCOL"])
		if cn > colnum then
			view["DELCOL"] = colnum .. "-" .. (cn - colnum)
		end
	end

	if linnum then
		local ln = tonumber(view["NUMLIN"])
		if ln > linnum then
			view["DELLIN"] = linnum .. "-" .. (ln - linnum)
		end
	end
end

function matrixview:getcell(lin, col)
	return self.view:getcell(lin, col)
end

function matrixview:grow_size(lsize, csize)
	local view = self.view
	local ln, cn = tonumber(view["NUMLIN"]), tonumber(view["NUMCOL"])
	if lsize > ln then
		view["ADDLIN"] = ln .. "-" .. (lsize - ln)
	end

	if csize > cn then
		view["ADDCOL"] = cn .. "-" .. (csize - cn)
	end
end

function matrixview:setcell(lin, col, v)
	self:grow_size(lin, col)
	self.view:setcell(lin, col, v)
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

