local nk = require "bgfx.nuklear"


local radio = { value = "item A"}
local r_items = { "item A","item B","item C","item D",
                  "item E","item F","item G","item H",
                  "item I","item J","item K","item L"   } 

local combo1 = 1
local combo_items1 = { "red","green","blue","dark","light"}

return function (nkimage)
    ui_header("单选按钮")
    nk.layoutRow('dynamic',35,4)
    nk.setFont(2)
    for k,v in pairs(r_items) do 
        nk.radio(v,radio)
    end 
end 
