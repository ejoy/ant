local nk = require 'nuklearlua'
local string = require "string"

local check_sel = {
    value = true
}

local winskin = nk.loadImage("skin/gwen.png")

local style = {
     ['window'] = {
        ['header'] = {
           ['normal'] = nk.subImage( winskin,128,0,127,24), 
           ['hover']  = nk.subImage( winskin,128,0,127,24), 
           ['active'] = nk.subImage( winskin,128,0,127,24), 

           ['label normal'] = '#00ff00',
           ['label hover']  = '#00ff00',
           ['label active'] = '#00ff00',
           ['label padding'] = { x=1,y=1},
           ['text background'] = '#00000000',
        },
        ['background'] = '#7f7f7f',
        ['fixed background'] = nk.subImage( winskin,128,23,127,104),
    },
    ['button'] = {
        ['normal'] = nk.subImage( winskin,384,336,127,31),
        ['hover']  = nk.subImage( winskin,384,368,127,31),     -- "#FF0000",
        ['active'] = nk.subImage( winskin,384,400,127,31),     -- "#00FF00",
        ['text background'] = '#00000000',
        ['text normal'] = '#ff0000',
        ['text hover']  = '#00ff00',
        ['text active'] = '#ffffff',
        ['text alignment'] = 'centered',
        ["border"] = 1,
        ["rounding"] = 1,
        ["padding"] = {x=2,y=2},
		["image padding"] = {x=2,y=2},
		["touch padding"] = {x=1,y=1},
    },
    ['checkbox'] = {
		['normal'] = nk.subImage( winskin,464,32,15,15),
		['hover']  = nk.subImage( winskin,464,32,15,15),
		['active'] = nk.subImage( winskin,464,32,15,15),
		['cursor normal'] = nk.subImage( winskin,450,34,11,11),
		['cursor hover']  = nk.subImage( winskin,450,34,11,11),
		['text normal'] = '#00ee00',
		['text hover']  = '#00ee00',
		['text active'] = '#003300',
		['text background'] = '#d3ceaa'
	},
    ['slider'] = {
        ['normal'] = '#ff000000',
        ['hover'] = '#00000000',
        ['active'] = '#00000000',
        ['bar normal'] = '#9c9c9c',
        ['bar hover'] = '#9c9c9c',
        ['bar active'] = '#9c9c9c',
        ['bar filled'] = '#9c9c9c',
        ['cursor normal'] = nk.subImage( winskin,418,33,11,14),
        ['cursor hover' ] = nk.subImage( winskin,418,49,11,14),
        ['cursor active'] = nk.subImage( winskin,418,64,11,14),
        --['bar height'] = 1,
        ['cursor size'] = {x=14,y=18},
    },
    ['progress']= {
        ['normal']  = '#e7e7e7',
        ['hover']  = '#e7e7e7',
        ['active'] = '#e7e7e7',
        ['cursor normal'] = '#3ff23f', -- nk.subImage( winskin,418,33,11,14),
        ['cursor hover' ] = '#3ff23f', --nk.subImage( winskin,418,49,11,14),
        ['cursor active'] = '#3ff23f', --nk.subImage( winskin,418,64,11,14),
        ['border'] = 1,
        ['border color'] = '#757575',
        ['padding'] = {x=0,y=0},
        ['rounding'] = 4,
    },
    ['combobox'] = {
        ['normal'] = '#d8d8d8',
        ['hover'] = '#d8d8d8',
        ['active'] = '#d8d8d8',
        ['label normal'] = '#9c9c9c',
        ['label hover']  = '#9c9c9c',
        ['label active'] = '#9c9c9c',
        ['border color'] = '#9c9c9c',
        ['border'] = 1,
        ['rounding' ] = 1,
    },
    ['radio'] = {
        ["normal"] = nk.subImage( winskin,464,64,15,15),
		["hover"] = nk.subImage(winskin,464,64,15,15),
		["active"] = nk.subImage(winskin,464,64,15,15),

		["cursor normal"] = nk.subImage(winskin,451,67,9,9),
		["cursor hover"] = nk.subImage(winskin,451,67,9,9),

		["text normal"] = "#6f6f6f",
		["text hover"] = "#6f6f6f",
		["text active"] = "#6f6f6f",
    },
    ---[[
    ['property'] =
    {
        ["normal"] = "#D8D8D8",
        ["hover"]  = "#D8D8D8",
        ["active"] = "#D8D8D8",
    
        ['border color'] = '#000000',
    
        ["label normal"] = "#6F6F6F",
        ["label hover"] = "#6F6F6F",
        ["label active"] = "#6F6F6F",
   
        ["border"] = 1,
        ["rounding"] = 4,
        ['padding'] = {x=2,y=2},

        ["inc button"] = {
            ['normal'] = '#D8D8D8',
            ['hover']  = '#D8D8D8',
            ['active'] = '#D8D8D8',
            ['border color'] = '#00000000',
            ['text background'] = '#00000000',
            ['text normal'] = '#6f6f6f',
            ['text hover']  = '#6f6f6f',
            ['text active'] = '#6f6f6f',
        },
        ["dec button"] = {
            ['normal'] = '#D8D8D8',
            ['hover']  = '#D8D8D8',
            ['active'] = '#D8D8D8',
            ['border color'] = '#00000000',
            ['text background'] = '#00000000',
            ['text normal'] = '#6f6f6f',
            ['text hover']  = '#6f6f6f',
            ['text active'] = '#6f6f6f',
        },        
    ---[[
       ["edit"] = {
            ['normal'] = '#D8D8D8',
            ['hover'] = '#D8D8D8',
            ['active'] = '#D8D8D8',
            ['border color'] = '#00000000', --'#3E3E3E',
            ['cursor normal'] = '#6F6F6F',
            ['cursor hover'] = '#6F6F6F',
            ['cursor text normal'] = '#FF6F6F',
            ['cursor text hover'] = '#FF6F6F',
            ['text background'] = '#00000000',
            ['text normal'] = '#FF6F6F',
            ['text hover'] = '#FF6F6F',
            ['text active'] = '#FF6F6F',
            ['selected normal'] = '#5F5F5F',
            ['selected hover'] = '#5F5F5F',
            ['selected text normal'] = '#FF5F5F',
            ['selected text hover'] = '#FF5F5F',
            ['border'] = 1,
            ['rounding'] = 2,
       },
    --]]
    },

    ["edit"] = 
    {
        ['normal'] = '#D8D8D8',
        ['hover'] = '#D8D8D8',
        ['active'] = '#D8D8D8',
        ['border color'] = '#000000', --'#3E3E3E',
        ['cursor normal'] = '#6F6F6F',
        ['cursor hover'] = '#6F6F6F',
        ['cursor text normal'] = '#FF6F6F',
        ['cursor text hover'] = '#FF6F6F',
        ['text background'] = '#00000000',
        ['text normal'] = '#2F2F6F',
        ['text hover'] = '#2F2F6F',
        ['text active'] = '#2F2F6F',
        ['selected normal'] = '#6F5F5F',
        ['selected hover'] = '#6F5F5F',
        ['selected text normal'] = '#00FFFF',
        ['selected text hover'] = '#00FFFF',
        ['border'] = 1,
        ['rounding'] = 2,
   },
   ---[[
   ['combobox'] = {
      
        ['normal'] = '#D8D8D8',
        ['hover'] = '#D8D8D8',
        ['active'] = '#D8D8D8',
 
        ['border color'] = '#000000', --'#3E3E3E',
        
        ["label normal"] = "#2F6F6F",
        ["label hover"] = "#2F6F6F",
        ["label active"] = "#2F6F6F",

        ['symbol normal'] = "#2F6F6F",
        ['symbol hover'] = "#2F6F6F",
        ['symbol active'] = "#2F6F6F",
        
        ['border'] = 1,
        ['rounding'] = 4,

        ["button"] = {
            ['normal'] = '#D8D8D8',
            ['hover']  = '#D8D8D8',
            ['active'] = '#D8D8D8',
            ['border color'] = '#00000000',
            ['text background'] = '#00000000',
            ['text normal'] = '#6f6f6f',
            ['text hover']  = '#6f6f6f',
            ['text active'] = '#6f6f6f',
        },        
   },
   --]]
}

local slider_value = { value = 75 }
local progress_value = { value = 25}
local radio_c = {value = 'item a'}
local property_value = { value = 6 }
local edit_value = { value = 'edit box mode: \n test test test in pane'} 
local combo = {value = 3, items = {'A item', 'B item', 'C item'}}

local font_id = nk.loadFont("font/stxingka.ttf",24)  --"font/msyh.ttf",18) --"font/stxingka.ttf",18);

return function ()
    -- 这里初始化，将被多次执行
    
    nk.setFont(font_id);
    --   仅仅是 skin header，window 的空窗口, 需要3个 draw calls???  还是一张atlas,而非独立图片??
    --   有可能 background 绘制一次，header，window 各绘制一次，尽管是atlas ？
    nk.setStyle ( style )
    if nk.windowBegin("Atlas Skin Example",200,200,400,480,"title","movable") then
    ---[[
        ---[[
        nk.layoutRow('dynamic',20,1)
        nk.label("Skin example !","centered","#FF0000" )
        nk.label("setStyle can change image skins, colors, padding, font, and more. ",
                 "left","#FF0000")
        --]]
        ---[[
        nk.label("slider","left","#ff0000")
        nk.slider(slider_value,0,100,1)
        --]]
        ---[[
        nk.label("progress","left","#00ff00")
        nk.progress(progress_value,100,true)
        --]]
        nk.layoutRow('dynamic',24,4)
        nk.radio("item a",radio_c)
        nk.radio("item b",radio_c)
        nk.radio("item c",radio_c)
        nk.radio("item d",radio_c)

        nk.layoutRow('dynamic',30,1)
        nk.property('Property', property_value,0, 100, 0.5, 0.05)
        nk.layoutRow('dynamic',60,1)
        nk.edit("edit box",edit_value)
        nk.layoutRow('dynamic',20,1)

        nk.label("combobox","left","#0000ff")
        nk.combobox(combo,combo.items)

        nk.spacing(2);
        ---[[
        nk.layoutRow('dynamic',30,3)
        nk.spacing(1);
        nk.button("apply")
        --]]
        ---[[
        --nk.spacing(2);
        nk.checkbox("check style",check_sel)
        --]]
    -- ]]
    end 
    nk.windowEnd() 
    nk.unsetStyle() 
    nk.setFont(0);
end
