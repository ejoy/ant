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

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

local function solve_depend(res, step, pipeline, what)
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
				table_append(res, step[name])
				step[name] = false
			end
		elseif type == "pipeline" then
			solve_depend(res, step, pipeline, name)
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
		local proxy = {}
		for step_name, func in pairs(s.methodfunc) do
			table.insert(res[step_name], { func, proxy, name, step_name, packname })
		end
	end
	setmetatable(res, nil)

	for _, pl in pairs(w._class.pipeline) do
		if pl.value then
			for _, v in ipairs(pl.value) do
				if v[1] == "stage" then
					mark[v[2]] = nil
				end
			end
		end
	end

	for name in pairs(mark) do
		error(("pipeline is missing step `%s`, which is defined in system `%s`"):format(name, res[name][1][3]))
	end
	w._systems = res
end

function system.lists(w, what)
	local res = {}
	solve_depend(res, w._systems, w._class.pipeline, what)
	return res
end

local switch_mt = {}; switch_mt.__index = switch_mt

function switch_mt:enable(name, enable)
	if enable ~= false then
		enable = nil
	end
	if self[name] ~= enable then
		self.__needupdate = true
		self[name] = enable
	end
end

function switch_mt:update()
	if self.__needupdate then
		local index = 1
		local all = self.__all
		local list = self.__list
		for i = 1, #all do
			local name = all[i][5] .. "|" .. all[i][3]
			if self[name] ~= false then
				-- enable it
				list[index] = all[i]
				index = index + 1
			end
		end
		for i = index, #list do
			list[i] = nil
		end
		self.__needupdate = nil
	end
end

function system.list_switch(list)
	local all_list = {}
	for k,v in pairs(list) do
		all_list[k] = v
	end
	return setmetatable({
		__list = list,
		__all = all_list,
	} , switch_mt )
end

return system
