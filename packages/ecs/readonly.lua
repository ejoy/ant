local function readonly(t)
    local mt = {}
    function mt:__index(k)
        local v = t[k]
        if type(v) == "table" then
            return readonly(v)
        end
        self[k] = v
        return v
    end
    local proxy = setmetatable({}, mt)
    local function readonly_next(_, k)
        local newk = next(t, k)
        if newk ~= nil then
            assert(type(newk) ~= "table") -- TODO
            return newk, proxy[newk]
        end
    end
    return setmetatable({}, {
        __index = proxy,
        __newindex = function()
            error("readonly", 2)
        end,
        __pairs = function()
            return readonly_next
        end
    })
end

return readonly
