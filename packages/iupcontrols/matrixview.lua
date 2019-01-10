local ctrlutil = require "util"
local observer = require "common.observer"

require "iupluacontrols"

local matrixview = {}; matrixview.__index = matrixview

function matrixview:resize(cnum, lnum)
	local view = self.view
	view.NUMCOL = cnum
	view.NUMLIN = lnum
end

function matrixview:getuserdata(lin, col)
	local ud = assert(self.ud)
	local c = ud[col]
	if c then
		return c[lin]
	end
	return nil
end

function matrixview:setuserdata(lin, col, data)
	local ud = assert(self.ud)
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
		local cn = tonumber(view["NUMCOL"] or 0)
		if cn > colnum then
			view["DELCOL"] = (colnum + 1) .. "-" .. (cn - colnum)
		end
	end

	if linnum then
		local ln = tonumber(view["NUMLIN"] or 0)
		if ln > linnum then
			view["DELLIN"] = (linnum + 1) .. "-" .. (ln - linnum)
		end
	end
end

function matrixview:getcell(lin, col)
	return self.view:getcell(lin, col)
end

function matrixview:size()
	local view = self.view
	return tonumber(view["NUMLIN"]), tonumber(view["NUMCOL"])
end

function matrixview:grow_size(lsize, csize)
	local ln, cn = self:size()
	if lsize > ln then
		local s = ln or 0
		self.view["ADDLIN"] = s .. "-" .. (lsize - s)
	end

	if csize > cn then
		local s = cn or 0
		self.view["ADDCOL"] = s .. "-" .. (csize - s)
	end
end

function matrixview:setcell(lin, col, v)
	self:grow_size(lin, col)
	self.view:setcell(lin, col, v)
end

function matrixview:append_line(value, ud)
	local ln = self:size()
	if ud then
		assert(#value == #ud)
	end
	local newline = ln + 1
	for icol=1, #value do
		local v = value[icol]
		local uv = ud and ud[icol] or nil

		self:setcell(newline, icol, v)
		if uv then
			self:setuserdata(newline, icol, uv)
		end
	end
end

function matrixview:focus()
	local view = self.view

	local l, c = view.FOCUSCELL:match("(%d+):(%d+)")
	return tonumber(l), tonumber(c)
end

function matrixview:remove_line(lineidx)
	lineidx = lineidx or self:focus()
	local view = self.view
	view.DELLIN = lineidx
end

local function create_view(config)
	local param = {
		COLNUM = 0, LINNUM = 0
	}
	if config then
		for k, v in pairs(config) do
			param[k] = v
		end
	end

	return iup.matrix(param)	
end

function matrixview.new(config)
	local c = ctrlutil.create_ctrl_wrapper(function ()
		return create_view(config)
	end, matrixview)
	
	c.observers = observer.new()
	return c
end

return matrixview

