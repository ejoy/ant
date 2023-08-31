local pm = require "packagemanager"

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

return function (w, importor, package)
    local ecs = { world = w }
    function ecs.system(name)
        local fullname = package .. "|" .. name
        local r = w._class.system[fullname]
        if r == nil then
            log.debug("Register system   ", fullname)
            r = {}
            w._class.system[fullname] = r
            importor.system(fullname)
        end
        return r
    end
    function ecs.component(fullname)
        local r = w._class.component[fullname]
        if r == nil then
            log.debug("Register component", fullname)
            r = {}
            w._class.component[fullname] = r
            importor.component(fullname)
        end
        return r
    end
    function ecs.require(fullname)
        local pkg, file = splitname(fullname)
        if not pkg then
            pkg = package
            file = fullname
        end
        return w:_package_require(pkg, file)
    end
    function ecs.clibs(name)
        return w:clibs(name)
    end
    return ecs
end
