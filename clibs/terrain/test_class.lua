local lterrain = require 'lterrain'
local util = require 'utilclass'


----- simple  ------
print("---New -----")
local c1 = Class( "AClass", {first="abc",second="def",third="123"} )  -- class with some attrib field 
c1.abc = 10

print("---Check-----")
print("classname = "..c1.__cname)
for k,v in pairs(c1) do
  print( 'k= '..k..' '..'type = '..type(v)  )
  if type(v) ~= "function" and type(v) ~= "table" then 
	print(v)
  end 
end 

print("---Attrib----")
print(c1[1])
print(c1.abc)
print(c1.new)
print(c1.__index)
print(c1.super)
print(c1.super.first)
print(c1.super.second)
print(c1.super.third)

print(c1.first)
print(c1.second)
print(c1.third)

print("---super---")
print(c1.super.first)
print(c1.super[2])     -- nil
print(c1.super[3])     -- nil



print("------- data set -------")

local cobj = Class("obj")               -- 创建一个新类
print(cobj.__cname)
cobj.objname = "cobj"
print("create new table objs")
local objs = Dict.new{ name = 'iron man',age = 100,gender = "male" }

for k,v in ipairs(objs) do 
  print("k= "..k..':'.."v "..v)
end 
print("table ")
print("name = "..objs.name)
print("age = "..objs.age )
print("gender = "..objs.gender)


print("create class inherited from table objs")
local hero = Class("HERO",objs,cobj)      -- 从表和类多重继承
hero.attack = 2000
hero.health = 100

print("class = "..hero.__cname)
print("name = "..hero.name)
print("age = "..hero.age )
print("gender = "..hero.gender)
print("attack = "..hero.attack)
print("health = "..hero.health)
print("objname = "..hero.objname)

print("---super---")
print(hero.super[1].name)                 --多继承访问
print(hero.super[2].objname)

local hero2 = hero.new()                  -- New Instance
print("hero2 = "..hero2.name)
hero2.name = "hulk"
print("hero = "..hero.name)
print("hero2 = "..hero2.name)
print("hero2 attack = "..hero2.attack)
print("hero2 health = "..hero2.health)
print("hero2 objname = "..hero2.objname)


local hero3 = Class("New Hero",hero)      -- 派生，单重继承
hero3.name = "spider man"
hero3.age = 16
print("hero3 = "..hero3.name)
print("hero3.age = "..hero3.age)

local hero4 = Class("Transfomer",hero3)
print("hero4 = "..hero4.name)
print("hero4.age = "..hero4.age)


print("---- hero remove key: attack,age ")
hero:removeKeys("attack","age")

collectgarbage "collect"

if hero.attack then 
   print("attack = "..hero.attack)
end 
if hero.age == nil then 
   print("hero.age release")
else 
   print("age = "..hero.age)
end

print("hero3 = "..hero3.attack)
print("hero3 = "..hero3.age)

-- New 产生的实例，当原类删除一个key 时，实例对应属性同时消失 ！
print("hero2 = "..hero2.attack)  -- access nil value ，instance key will be nil
print("hero2 = "..hero2.age)




