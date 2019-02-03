### 拆分出input controller
目前input controller的工作实际上在objcontroller.lua文件中需要拆分

### 分离出一个controller管理器
目前，camera和character的controller是冲突的，因为无办法确认哪个controller当前独占相关的输入（这也是为什么需要一个input controller的原因）
并且，camera实际上属于一个entity下的component，单独的一个camera_controller实际上不妥

### 需要camera和controller component
如何观察场景，实际上是由两部分组成：
1. camera控制可见的范围；
2. contronller控制交互后，camera的朝向和观察的位置；

那么，观察场景的对象如果是一个entity的话，这个entity就必须要有一个camera和controller，如：
```lua
local eid = world:new_entity(
	...,
	"camera", "controller",
	... 
)

--other code
...

local e = world[eid]
assert(type(e.controller) == "string")

local ctrlmgr = require "controller_manager"
ctrlmgr.activate(e.controller)
```

然后，这个entity能够在渲染的时候，被选取作为当前观察者（因为需要它的camera中的属性），也可以被称为当前的主角，main_character
这个所谓的main_character在不同的场景下是不同的。
- 在编辑器中，绑定的是一个叫做editor_maincharacter的对象
- 在runtime下，绑定的是一个用户控制的maincharacter
- 在重播的时候，绑定的是一个viewcharacter

选择不同的controller实际上是需要选择不同的*main* character，这个*mian*包含了相应的controller，可以通过manager来激活，后续input_controller产生的消息就会由这个controller来消费了。