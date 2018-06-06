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
    ui_header("子窗口 cell or list 演示")
    nk.setFont(2) 
    -- maybe surport get window remain rect function
    -- nk_window_get_content_region 
    -- top line
    nk.layoutRow("static",240,{600,400})
    -- left area
    if nk.areaBegin("list","title","border","movable","scrollbar") then
        nk.layoutRow("dynamic",30,{0.7,0.3} )
        local c = '#ffaa00'
        for i=1,20,1 do 
            if (i%2) ==1 then 
               c= '#00aaff'
            else
               c= '#ffaa00' 
            end  
            nk.label("context description .."..i.." {...}","left",c)
            nk.button("ok",nkimage)
        end 
        nk.areaEnd()
    end
    --right area
    if nk.areaBegin("list1","scrollbar") then
        nk.layoutRow("dynamic",30,{0.7,0.3} )
        local c = '#ffaa00'
        for i=1,20,1 do 
            if (i%2) ==1 then 
               c= '#00aaff'
            else
               c= '#ffaa00' 
            end  
            nk.label("context description .."..i.." { armor = 100b,weapon = 2000,........}","left",c)
            nk.button("ok",nkimage)
        end 
        nk.areaEnd()
    end
    -- buttom line 
    nk.layoutRow("dynamic",240,{0.2,-1} )
    -- left area
    if nk.areaBegin("button","scrollbar") then
        nk.layoutRow("dynamic",30,1)
        for i=1,20,1 do 
            nk.button("button "..i )
        end 
        nk.areaEnd()        
    end
    -- right area
    if nk.areaBegin("list2","scrollbar") then
        nk.layoutRow("dynamic",30,{0.7,0.3} )
        local c = '#ffaa00'
        for i=1,20,1 do 
            if (i%2) ==1 then 
               c= '#00aaff'
            else
               c= '#ffaa00' 
            end  
            nk.label("context description .."..i.." { armor = 100b,weapon = 2000,........}","left",c)
            nk.button("ok",nkimage)
        end 
        nk.areaEnd()
    end

end
