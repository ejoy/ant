local stringify_value

local pretty
local res
local indent

local function getindent()
    if pretty then
        return ("  "):rep(indent)
    end
    return ""
end

local function convertreal(v)
    local g = ('%.16g'):format(v)
    if tonumber(g) == v then
        return g
    end
    return ('%.17g'):format(v)
end

local function isarray(t)
    local k = next(t)
    if k == nil then
        -- empty table must be array
        return true
    end
    if type(k) == "string" then
        return false
    end
    assert(math.type(k) == "integer")
    return true
end

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

local function end_table(isroot)
    if not isroot then
        if res[#res] ~= false then
            res[#res] = res[#res]:sub(1,-2)
        else
            res[#res] = "{"
        end
    end
    res[#res+1] = isroot and getindent() or (getindent() .. "}")
    
    return isroot and "" or "{"
end

local function step_indent(step, isroot)
	if not isroot then
		indent = indent + step
	end
end

local function is_vector_array(t, maxnum)
    for i=1, maxnum do
        if type(t[i]) ~= "number" then
            return false
        end
    end

    return true
end

local function stringify_array(t, isroot)
    local max = 0
    for k in pairs(t) do
        if math.type(k) ~= "integer" then
            error("invalid table: mixed or invalid key types")
        end
        max = max > k and max or k
    end
	if max ~= 0 then
        step_indent(1, isroot)
        if is_vector_array(t, max) then
            local st = {}
            for i=1, max do
                st[#st+1] = stringify_value(t[i])
            end
            res[#res+1] = getindent()..table.concat(st, ', ')
            if not isroot then
                res[#res] = res[#res] .. ","
            end
        else
            for i = 1, max do
                local pos = #res+1
                res[pos] = false
                res[pos] = getindent()..stringify_value(t[i])
                if not isroot then
                    res[#res] = res[#res] .. ","
                end
            end
        end
        step_indent(-1, isroot)
    end
   
	return end_table(isroot)
end

local function stringify_key(v)
    if v:match "^[%a_][%w_]*$" then
        return v
    end
    return ("[%q]"):format(v)
end

local function stringify_object(t, isroot)
    local fmt = pretty and "%s = %s" or "%s=%s"
    step_indent(1, isroot)
    for k, v in sortpairs(t) do
        if type(k) ~= "string" then
            error("invalid table: mixed or invalid key types")
        end
        local pos = #res+1
        res[pos] = false
		res[pos] = getindent()..fmt:format(stringify_key(k), stringify_value(v))
		if not isroot then
			res[#res] = res[#res] .. ","
		end
    end
    step_indent(-1, isroot)
	return end_table(isroot)
end

function stringify_value(v, isroot)
    local t = type(v)
    if t == "nil" then
        return "nil"
    elseif t == "number" then
        if math.type(v) == "integer" then
            return ("%d"):format(v)
        end
        return convertreal(v)
    elseif t == "string" then
        return ("%q"):format(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "table" then
        if isarray(v) then
            return stringify_array(v, isroot)
        end
        return stringify_object(v, isroot)
    else
        error("invalid type: "..t)
    end
end

local function init(p)
    pretty = p
    indent = 0
	res = {false}	
end

local function stringify(v, p, asroot)
	init(p)
	local str = stringify_value(v, asroot)
    res[1] = asroot and str or "return"..str
    return table.concat(res, pretty and "\n" or nil)
end

return stringify