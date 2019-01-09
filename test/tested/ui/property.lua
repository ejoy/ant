local nk = require "bgfx.nuklear"

local pv = { value = 10}
local v = 20

return function (nkimage)
    ui_header("Property ")
    nk.setFont(2)
    nk.layoutRow('dynamic',35,4)
    nk.property("浮点值域",pv,0,100,0.5,0.05)
    v = nk.property("数字",v,0,100,2,1)
end 
