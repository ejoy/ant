local nk = require "bgfx.nuklear"


local combo = { value = 1 }
local combo_items = { "item A","item B","item C","item D",
                      "item E","item F","item G","item F",
                      "item H","item I","item J","item K"   } 

local combo1 = 1
local combo_items1 = { "red","green","blue","dark","light"}

return function (nkimage)
    ui_header("组合列表框")
    nk.layoutRow('dynamic',30,2)
    nk.setFont(2)
    nk.combobox(combo,combo_items)
    combo1 = nk.combobox(combo1,combo_items1,60,380,180)

end 
