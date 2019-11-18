if not string._extended then
    local log = log or print
    local ori_format = string.format
    string.format = function(str, first_arg, ...)

        if type(first_arg) == "table" and (select("#", ...) == 0) then
            local format_str, count = string.gsub(str, "{([_1-9a-zA-Z%%]+)}", function(idx)
                -- idx = tonumber(idx) or idx
                local value = first_arg[idx] or first_arg[tonumber(idx)]
                if not value then
                    log("[string.format]value is nil for key:"..idx)
                    return nil
                end
                return value
            end)
            return format_str
        else
            return ori_format(str, first_arg, ...)
        end
    end
    string._extended = true
end

if not setclose then
    setclose = function(close_fun)
        return setmetatable({},{__close = close_fun})
    end
end

if not class then
    class = require "common.class"
end