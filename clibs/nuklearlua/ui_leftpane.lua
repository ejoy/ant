local nk = require "nuklearlua"
local string = require "string"

local edit = { value = 'edit box mode: \n test test test in pane'} 

local check_edit = {value = false}
local check_cut  = {value = false}
local check_copy = {value = false}
local check_add  = true

local slide_value = 50
local progress_value = { value = 50}
local combo = {value = 3, items = {'A item', 'B item', 'C item'}}

local radio_c = {value = 'item a'}
local radio_n = {value = 'item 3'}

local property_value = { value = 6 }

function left_pane()
	-- "name","title",x,y,width,height,"border","title" window flags etc 
		if nk.windowBegin("Pane",0,0,200,800-100,"border","title",'scrollbar') then 
			nk.layoutRow('dynamic', 18, 1)
			-- "name"
			-- align = "left","right","centered","top left","top centered","top right","bottom left”,"bottom centered","bottom_right"
			-- color = "#FF0000"
			-- name,align,color
			-- name 
			---[[  1 draw call
			nk.label("Hello,Workspace!")
			nk.label('First Line !',"left")
			nk.label('Second Line !',"centered")
			nk.label( "Third Line !", "right","#FF0000")
		 

			-- button
			-- name
			-- name, "symbol"
			-- name, image 
			-- nil,  "#00ffff"   -- 颜色按钮不提供 title
			-- name, "underscore“
			-- name, image     -- 未提供
			-- 对齐使用全局设置,或应该再提供一个参数 ? 或提供一个 static 固定定位
			-- (name|nil), (symbol|image|color)
			--   1 draw call
			nk.button( "button"  ) 
			nk.button( "button","triangle down" )
			nk.button( "button","circle solid" )
			nk.button( "button","underscore" )
			nk.layoutRow('dynamic', 14, 2)
			nk.button( "button", "plus" )
			nk.button( "button", "minus")
			if nk.button( nil, "#ffff00" ) then
				print('----- yellow color ---')
			end 
			if nk.button( nil, "#ff0000" ) then 
				print('----  red color ----')
			end 	
			nk.layoutRow('dynamic', 18, 1)
			if(nk.button( "button" )) then
			print('============Button!=========')
			end 
			 
			-- edit 
			---  1 draw call
			nk.layoutRow('dynamic', 40, 1)
			local text, changed = nk.edit('edit box',edit)
			if changed then
				print( text )
			else
			    --print( "no changed ".. text ) 
			end 
			 

			-- checkbox
			---   1 draw call
			nk.layoutRow('dynamic',20,4)
			nk.checkbox("edit",check_edit)
			nk.checkbox("cut",check_cut)
			nk.checkbox("copy",check_copy)
			check_add = nk.checkbox("add",check_add)
			-- 
			-- slider 
			---   1 draw call
			nk.layoutRow('dynamic',20,2)
			nk.label("slider","left","#ff0000")
			slide_value = nk.slider(slide_value,0,100,1)
			-- 
			-- progress 
			---  0 draw call combine with slider 
			nk.layoutRow('dynamic',20,1)
			nk.label("progress","centered","#00ff00")
			nk.progress(progress_value,100,true)
			-- 
			-- combobox
			--  1 draw call,extend 2 draw call
			nk.label("combobox","right","#0000ff")
			nk.combobox(combo,combo.items)
			-- 

			-- radio 
			---  -- 0 draw call
			nk.layoutRow('dynamic',20,3)
			nk.radio("item a",radio_c)
			nk.radio("item b",radio_c)
			nk.radio("item c",radio_c)

			nk.layoutRow('dynamic',20,3)
			nk.spacing(3);
			--nk.layoutRow('dynamic',20,3)
			nk.radio("item 1",radio_n)
			nk.radio("item 2",radio_n)
			nk.radio("item 3",radio_n)
			nk.radio("item 1",radio_n)
			nk.radio("item 2",radio_n)
			nk.radio("item 3",radio_n)

			for idx=1,3,1 do 
				nk.radio("item 1",radio_n)
				nk.radio("item 2",radio_n)
				nk.radio("item 3",radio_n)
			end 

			for idx=1,12,1 do 
				nk.radio("item"..string.format("%02d",idx),radio_n) 
			end 
			-- 
			-- property
			---  1 draw call 
			nk.layoutRow('dynamic',20,1)
			nk.property('Property', property_value,0, 100, 0.5, 0.05)
			-- 
		end 
		nk.windowEnd()
end

return left_pane
