local hwi       = import_package "ant.hwi"
local lastname = "fxaa"
return setmetatable({}, {
    __index = function(t,name) 
    t[name] = hwi.viewid_generate(name, lastname) 
    return t[name] end
})