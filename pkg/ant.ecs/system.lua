local system = {}

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

local function solve_depend(funcs, symbols, step, pipeline, what)
	local pl = pipeline[what]
	if not pl or not pl.value then
		return
	end
	for _, v in ipairs(pl.value) do
		local type, name = v[1], v[2]
		if type == "stage" then
			if step[name] == false then
				error(("pipeline has duplicate step `%s`"):format(name))
			elseif step[name] ~= nil then
				for _, s in ipairs(step[name]) do
					funcs[#funcs+1] = s.func
					symbols[#symbols+1] = s.symbol
				end
				--step[name] = false
			end
		elseif type == "pipeline" then
			solve_depend(funcs, symbols, step, pipeline, name)
		end
	end
end

function system.solve(w)
	local mark = {}
	local res = setmetatable({}, {__index = function(t,k)
		local obj = {}
		t[k] = obj
		mark[k] = true
		return obj
	end})
	for fullname, s in sortpairs(w._class.system) do
		local packname, name = splitname(fullname)
		for step_name, func in pairs(s) do
			table.insert(res[step_name], {
				func = func,
				symbol = packname .. "|" .. name .. "." .. step_name,
			})
		end
	end
	setmetatable(res, nil)

	for _, pl in pairs(w._decl.pipeline) do
		if pl.value then
			for _, v in ipairs(pl.value) do
				if v[1] == "stage" then
					mark[v[2]] = nil
				end
			end
		end
	end

	for name in pairs(mark) do
		error(("pipeline is missing step `%s`, which is defined in system `%s`"):format(name, res[name][1].symbol))
	end
	w._systems = res
end

local function emptyfunc(info)
	local lines = info.activelines
	return next(lines, next(lines)) == nil
end

function system.lists(w, what)
	local funcs = {}
	local symbols = {}
	solve_depend(funcs, symbols, w._systems, w._decl.pipeline, what)
	local i = 1
	while i <= #funcs do
		local f = funcs[i]
		local info = debug.getinfo(f, "SL")
		if info.what ~= "C" then
			if emptyfunc(info) then
				log.warn(("`%s` is an empty method, it has been ignored. (%s:%d)"):format(symbols[i], info.source:sub(2), info.linedefined))
				table.remove(funcs, i)
				table.remove(symbols, i)
				goto continue
			end
		end
		i = i + 1
		::continue::
	end
	return funcs, symbols
end

return system
