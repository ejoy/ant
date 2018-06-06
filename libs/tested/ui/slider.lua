local nk = require "bgfx.nuklear"

local svt = { value = 10 }
local sv  = 20

return function (nkimage)
    ui_header("滑动条")
    nk.layoutRow("dynamic",30,{0.8,0.2} )
    nk.slider(svt,1,100,1)
    nk.label(svt.value,"left")
    sv = nk.slider(sv,1,1000,10)
    nk.label(sv,"left")

end 
