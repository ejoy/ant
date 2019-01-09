local nk = require "bgfx.nuklear"

return function( nkimage )
    local data = { value = 'field mode: write your text here ...\n'}
    local text = { value = 'a long time ago in a galaxy far,far away... \n luke skywalker...'}
    ui_header("编辑框")
    nk.setFont(2)
    nk.layoutRow("dynamic",60,1)
    nk.edit("field",data,"float")
    nk.setFont(1)
    nk.layoutRow("dynamic",200,1)
    nk.edit("box",text)
end
