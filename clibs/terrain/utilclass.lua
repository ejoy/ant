-- 基础数据表，基础类构建函数模拟
-- 用法:参考 test_class.lua 

-- 基础类模糊函数,暂时可使用，需要正式修改优化
Dict = {}
DictMeta = { __index = Dict}

--usage: Dict.new { name="micheal",age= 20,gender = "male" }
function Dict.new(...)
	local t = setmetatable({},DictMeta)
		for _,p in ipairs{...} do 
			 for k,v in pairs(p) do 
				 t[k] = v
			 end 
		end 
	return t
end
--usage: dict:removeKeys ( "gender","age" )
function Dict:removeKeys(...)
	for _,k in ipairs{...} do 
	  self[k] = nil
  end 
end 

-- 类构造函数
function newctor(class)
	return function(...)
		local obj = setmetatable( {},class )   			---  并非深度拷贝，当class 属性删除，class.New 实例同样消失
														---  class.new 想完全独立，则需要拷贝实现
		if not obj.init then        				    
		   obj.init = function() end			       ---  New Class 若该类不存在 init ,使用缺省
		end 
		obj:init(...)    				    			---  New Class 可以实现带参数带 init，实现自己的初始化工作
		return obj
	end 
end 

-- Class 简单模拟类创建函数，实现数据集合和行为的简单包装，方便使用
-- 参数1：要创建的类名称, 参数2： 空 or 数据集合 or 父类, 可单继承/多继承 
-- 参数2 ... 可以是属性集合，类，作为 super 父类成员存在，可以再扩充继承自函数，实现某种行为
-- super,new,__index 
-- usage: local c = Class ("class name",[talbe],[class_obj] )
function Class(classname,...)   
	local t = Dict.new(...)     						--- inherit all attrib,function 
	local root = {...}
	if #root == 0 then 
	  t.super = nil 
	else
														--- 单重继承/多重继承
	  t.super = root;   								--- super[1] ~ super[n]
	end 
	t.__index = t
	t.__cname = classname 
	print(">>> Create New Class ".. classname)
	t.new = newctor(t)
	return t
end










----------------------------------------------------------------------------
-- 更全面的类构造函数,可以继承自 function, table, userdata
-- 未完成未测试,预留
_setmetatableindex = function(t, index)
	 if type(t) == "userdata" then
		-- todo: inherit userdata 
     else
         local mt = getmetatable(t)
         if not mt then mt = {} end
         if not mt.__index then
             mt.__index = index
             setmetatable(t, mt)
         elseif mt.__index ~= index then
             _setmetatableindex(mt, index)
         end
     end
end

-- 更全面的类构造函数,可以继承自 function, table, userdata
function class(classname,...)
	local cls = { __cname = classname }

	local supers = {...}
	for _,super in ipairs(supers) do 
	  local stype = type(super)
	  if stype == "function" then 
	     cls.__create = super								--- 如果是继承自函数 
	  elseif stype == "table" then 
	     if super[".isclass"] then							--- 如果是已存在的定义类
		   cls.__create = function() super:create() end 
		 else 
		   cls.__supers = cls.__supers or {} 
		   cls.__supers[#cls.__supers+1] = super			--- lua 自定义
		   if not cls.super then 
		      cls.super = super 
		   end 
		 end 
	  end 
	end 

	cls.__index = cls 
	if not cls.__supers or  #cls.__suppers == 1 then
	   setmetatable( cls,{__index = cls.super} )         	--- 单继承
	else 
	   setmetatable ( cls, 
	                { __index = function(_, key)		    --- 函数，提供对所有父类的检索
						local supers = cls.__supers
						for i = 1, #supers do
							local super = supers[i]
							if super[key] then return super[key] end
						end
					  end
				    } )
	end 

	if not cls.ctor then
	   cls.ctor = function() end 
	end

	cls.new = function(...)
	    local inst
		if cls.__create then  -- 
		   inst = cls.__create(...)
		else 
		   inst = {}     									 --- lua class
		end  
		_setmetatableindex(instance,cls)
		instance.class = cls 
		inst:ctor(...)
		return inst 
	end 
	cls.create = function(_,...)
	   return cls.new(...)
	end  

	return cls 
end
