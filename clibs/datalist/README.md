## datalist

A data format used by our game engine. It's just like a simpler version of yaml, or an enhanced version of json. 

### A simple dictionary
key should be a string without space, use : or = to separate value.

```lua
a = datalist.parse [[
x : 1 # comments ...
y = 2 # = is equivalent to :
100 : number
]]

-- a = { x = 1, y = 2, ["100"] = "number" }
```

Or you can use datalist.parse_list to parse dictionary into a list with key value pairs.
```lua
a = datalist.parse_list [[
x : 1
y : 2
]]

-- a = { x , 1, y , 2 }
```

### A simple list
Use white space ( space, tab, cr, newline , etc) to separate atoms.
```lua
a = datalist.parse[[
hello "world"
0x1p+0 # hex float 1.0
2 
0x3 # hex integer
nil
true 
false
on  # true
off # false
yes # true
no  # false
]]

-- a = { "hello", "world", 1.0, 2, 3, nil, true, false, true, false, true, false }
```

### section list
--- can be used to separate sections of a list.
```lua
a = datalist.parse [[
---
x : hello
y : world
---
1 2 3
]]

-- a = { { x = "hello", y = "world" }, { 1,2,3 } }
```

### Use indent or {} to describe a multilayer structure

```lua
a = datalist.parse [[
x :
  1 2 3
y :
  dict : "hello world"
z : { foobar }
]]

-- a = {  x = { 1,2,3 },  y = { dict = "hello world" }, z = { "foobar" } }

b = datalist.parse [[
---
hello world
  ---
  x : 1
  y : 2
]]

-- a = { "hello", "world", { x = 1, y = 2 } }
```

### Use tag to reference a structure

tag is a 64bit hex integer id.

```lua
a = datalist.parse [[
--- &1   # This structure tagged by 1
"hello\nworld"
---
x : *1   # The value is the structure with tag 1
]]

-- a = { { "hello\nworld" } , { x = { "hello\nworld" } } }
```

### Converter

The structure in [] would be convert by a user function.

```lua
a = datalist.parse( "[ 1, 2, 3 ]" , function (t)
  local s = 0
  for _, v in ipairs(t) do  -- t = { 1,2,3 }
    s = s + v
  end
  return s)
  
-- a = { 6 }

a = datalist.parse([[
[ sum 1 2 3 ]
[ vec 4 5 6 ]
]], function (t)
  if t[1] == "sum" then
    local s = 0
    for i = 2, #t do
      s = s + t[i]
    end
  elseif t[2] == "vec" then
    table.remove(t, 1)
  end
  return t)
  
-- a = { 6 , { 4,5,6 } }
```
