local nk = require "bgfx.nuklear"

-- use layoutRow and spacing 

function ui_header(title,color)
    nk.setFont(1)
    nk.layoutRow("dynamic",50,1)
    if color ~= nil then
        nk.label(title,"left",color)
    else 
        nk.label(title,"left")
    end 
end 

return function( nkimage )
    ui_header("布局方式")
    ui_header("widget centered=======","#ff00dd")
    nk.layoutRow('dynamic',120,{0.2,0.6,0.2} )
    nk.spacing(1) 
    nk.button("image",nk.subImage(nkimage,32,25,64,52))  -- label + image  maybe need align parameter
    nk.button("image",nk.subImage(nkimage,32,25,64,52))  -- label + image  maybe need align parameter

    ui_header("widget static ========")
    nk.layoutRow('static',120,{130,120,120} )
    nk.spacing(1)
    nk.button("image",nk.subImage(nkimage,32,25,64,52))  -- label + image  maybe need align parameter
    nk.button("image",nk.subImage(nkimage,32,25,64,52))  -- label + image  maybe need align parameter
end
