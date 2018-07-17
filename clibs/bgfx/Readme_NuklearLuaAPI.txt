
* windowBegin/End 不允许嵌套

1. windowBegin   
   param   :  name,title,x,y,width,height,style1,style2，....
   param s : "name",["title"],x,y,width,height,["border"],["title"]
   style = "border", "movable", "scalable", "closable","minimizable","scrollbar","title","scroll auto hide","background"

   sample:
      if nk.windowBegin("Demo",0,800-100,1200,100,"border","title") then
      end
   
2. windowEnd
   每一个windowBegin，都需要以 windowEnd 配对结束
   if windowBegin(...) then 
      do something
   end  
   windowEnd()
   

3. layoutRow  布局函数
   param: layout mode, 
               height, 
              [item_width] or  {...}, cols
              其中{...} 	 {0.3,0.2,0.3}           百分比方式,{}表长度指定当前行的列数，表内的数字指定宽度，指定每个控件要占据的一行的百分比空间，随窗口缩放
		 {120，100，180}   固定值方式,{}表长度指定当前行的列数，表内的数字指定宽度，指定每个控件要占据的像素长度，不随窗口缩放而变化
   sample:
   layoutRow("Dynamic",30,1)                --3参数- 动态布局，ui控件高30像素，整行 1列，ui将填充一整行
   layoutRow("Static",30,50,1)                --4参数- 静态布局，ui控件高30像素，整行 1列，ui控件50像素宽
   
   layoutRow("Dynamic",30,{0.2,0.3,0.4,0.1} )    -- 4 列 行的百分比
   layoutRow("Static",30, {100,100,300,100} )    -- 4 列 像素宽度
  
   
4. label 
   param: name, align, color
   aligin = "left","right","centered","top left","top centered","top right","bottom left”,"bottom centered","bottom_right"
            or "wrap"
  
   sample: 
   nk.label("Hello,Workspace!")
   nk.label('First Line !',"left")
   nk.label('Second Line !',"centered")
   nk.label( "Third Line !", "right","#FF0000")
   
5. button
   param：name,                                        -- 当不填写name时，使用nil 
	[ color | symbol | image ]            -- 
		  
   symbol = "underscore","circle solid","circle outline","rect solid","rect outline","triangle up"
                  "triangle down","triangle left","triangle right","plus","minus"
   return: true                                     --  if button  pressed

   sample:   
   nk.button("apply","triangle down")         -- symbol 
   nk.button( nil,"#0000FF")                        -- color 
   nk.button("apply",nkimage)                    -- image ( id,w,h, rx,ry,rw,rh ) 作为button的一个子图标
                                                                 -- 纯粹使用图标按钮，则需要 setStyle 风格化模式
6. widget 
   nk.layoutRow
   nk.label
   nk.spacing 			  -- 布局组合使用，构建标题栏，可以形成一个 ui_header 函数   

7. image 
   params：nk_image = { handle,w,h,rx,ry,rw,rh }     -- nk_image  make from loadImage(disk),makeImage(id),makeImageMem(mem)

   sample:
   nk.image( image ) 
   
8. edit
   parameter:   editmode ,value table , [limit]
   editmode = "simple","field","box","editor" 

   sample:
      local text = {value = “hello,world" }
      limit = "hex","ascii","float","binary","oct","decimal"
      nk.edit("editor",text)
   
9. progress
   params: 
          value                   --  number or { value = 1 }
          max                     --  max limit 
          [modifiable]          --  if can modify
   return:
          changed state      -- if input value  as  table
          value number      -- if input value  as  number 

   sample:
   local pv = {value = 10}
   nk.progress(pv,max,true)
   
10. slider 
   params: value   number = 10 or  table { value = 10 } 
           min     0
		   max     100
		   step    1
		   
   return  changed state or value like progress 
   sample:
   local v = { value = 10 }
   nk.slider( value ,0,100,1)
   
11. checkbox
   params: name 
           value   boolean or { value = true } 
   
   sample:	   
   value = nk.checkbox("seleted",value)
   
12.combobox
  params: value                   // index  or table { value = 1 }   //index to items 
          items   table { "item a","item b" }
		  [item height]           //item row height in drawlist, custum style 
		  [w]                     //drawlist window w 
		  [h]                     //drawlist window h 
  sample:
  local idx = 1
  idx = nk.combobox(idx, items)
  
13. property 
  params: 	  name 
		  value       // value or  table { value = ...}
		  min 
		  max
		  step
		  motion step 
   sample:
	local v = { value = 10 }
	nk.property("浮点值域",pv,0,100,0.5,0.05)		  
	
14. area   当前没有子区域的scroll，类似popup,combobox drawlist，或许需要group 来实现区域管理 ？
           提供子窗口管理 ！
   params: name,     // area window‘s name
           flags     //scrollbar,border etc,window flags 
   sample:
	nk.areaBegin("subWindow","scrollbar")
	nk.areaEnd()
	
15. irrbutton  不规则按钮，可拖拽,无边框按钮,-可缩放
params:
    name  : button name
	rc    : pos & size
	image : use as button addition image,not like style button has three status
	flags : move flags string ,only “movable", default no movable 

   sample:	
	-- 加外部贴图模式，无风格，不可移动
	nk.irrbutton("irrbutton",rc,im_joy);
	-- 使用皮肤风格按钮，可以移动
	nk.irrbutton("attack ",rc_attack1,"movable" 

16. joystick  虚拟游戏杆
params:
    name       : for control name 
	rc         : position & size 
	inner_size : joystick size ,ratio of rc (0.5-0.7) 
	radius     : radius, ratio of rc radius (0.1-1.0-n)
	dir        : vec2  return normalize direction 
	im_base    : image background for joystick
	im_joy     : image joystick 

   sample:	
	local rc = { x= 120,y=180,w=200,h=200 }    -- pos & size
	local radius = 0.9  --rc_joystick.w/2*0.9  -- joystick move radius use ratio 
	local joystick_size = 0.7                  -- joystick image size use ratio 
	
	-- return joystick direction 
	local dir  = { x=0,y=0 }  
	
	nk.joystick("joy",rc_joystick,joystick_size,radius,dir,im_base,im_joy)
	
	local speed = 2 
	local move = dir
	move.x *= speed
	move.y *= speed
	
17. Anibutton  动画按钮


18. modelIcon  模型显示控件

19. layoutSpaceBegin/layoutSpaceEnd 自由布局函数
    joystick
	irrbutton 等控件属于可以任意定位的函数，需要在这个区间使用



   

   
   
   
   
   
   



 

   