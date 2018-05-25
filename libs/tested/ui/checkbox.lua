local nk = require "bgfx.nuklear"


local check_edit = {value = false}
local check_cut  = {value = false}
local check_copy = {value = false}
local check_add  = true

return function (nkimage)
    ui_header("多选框")
    nk.setFont(2)
    nk.layoutRow('dynamic',20,4)
    nk.checkbox("edit",check_edit)
    nk.checkbox("cut",check_cut)
    nk.checkbox("copy",check_copy)
    check_add = nk.checkbox("add",check_add)


end 
