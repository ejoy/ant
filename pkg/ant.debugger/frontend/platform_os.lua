local platform = require 'bee.platform'

local m = {
    OS = platform.OS,
}

function m.init(args)
    if platform.OS == "Windows" and args.useWSL then
        m.OS = "Linux"
        args.useWSL = true
        return
    end
    m.OS = platform.OS
    args.useWSL = nil
end

return setmetatable(m, {__call = function() return m.OS end})
