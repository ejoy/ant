--example begin
--[[ 
base_type=class("base_type")       -- 定义一个基类 base_type
function base_type:_init(x)  -- 定义 base_type 的构造函数
    print("base_type _init")
    self.x=x
end
 
function base_type:print_x()    -- 定义一个成员函数 base_type:print_x
    print(self.x)
end
 
function base_type:hello()  -- 定义另一个成员函数 base_type:hello
    print("hello base_type")
end

class_a=class("class_a",base_type)   -- 定义一个类 class_a 继承于 base_type
function class_a:_init(a,b)    -- 定义 class_a 的构造函数
    print("class_a _init",a)
    base_type._init(self,b)    --！！！这自己显式调用base_type._init，方便控制基类的init时机和参数
end
 
function class_a:hello()   -- 重载 base_type:hello 为 class_a:hello
    print("hello class_a")
end


-- 现在可以试一下了：

a=class_a.new(1111,222)    -- 输出两行，base_type _init 和 class_a _init 。这个对象被正确的构造了。
a:print_x()             -- 输出 222 ，这个是基类 base_type 中的成员函数。
a:hello()               -- 输出 hello class_a
print(a._type)          -- 输出 class_a
print(class_a._type)       -- 输出 class_a
print(base_type._type)  -- 输出 base_type

--test is_instance
class_aa = class("class_aa",class_a)
class_b=class("class_b",base_type)
print(a:is_instance(class_a) and class_a.is_instance(a))  -- true
print(a:is_instance(base_type) and base_type.is_instance(a)) -- true
print(a:is_instance(class_aa) or class_aa.is_instance(a)) -- false
print(a:is_instance(class_b) or class_b.is_instance(a))  -- false
]]--
local function class(class_name,super)
    local class_type={}
    class_type._init=false
    class_type._type = class_name
    class_type.new=function(...)
        local obj=setmetatable({},{ __index=class_type })
        if class_type._init then
            class_type._init(obj,...)
        end
        return obj
    end
    --2 equivalent way to use
    --1、ClassA.is_instance(objA) 
    --2、objA:is_instance(ClassA)
    local is_instance
    is_instance = function(obj,the_class)
        the_class = the_class or class_type
        local mt = getmetatable(obj)
        if mt then
            local mt_index = mt.__index
            if mt_index == the_class then
                return true
            else
                return is_instance(mt_index,the_class)
            end
        else
            return false
        end
    end
    class_type.is_instance = is_instance

    if super then
        setmetatable(class_type,{__index=super})
    end
    return class_type
end

return class

