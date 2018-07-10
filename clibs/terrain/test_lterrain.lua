local terrain = require 'lterrain'

-- 测试 terrain data 作为userdata 的创建，与回收
-- 测试 lua 计算效率
local obj = terrain.create()     -- 修改后，必须使用 terrain.lua 作为上一层的API 

-- active __index tested
-- 可以根据实际需求产生对应的查询函数，不要试图使用一个接口，已属性变量方式完成所有功能
--print("terrain get width = "..obj.gridWidth)
--print("terrain get height = "..obj.gridLength)

-- userdata 删除测试 
obj = nil

-- 不能直接删除，gc 管理
--terrain.close(obj)
---[[
math.randomseed(os.time())

--- 计算效率测试 
-- 257,513,1025 效率太慢，不可接受
local size = 1025
local tl = {} 
for i=1,size do
    for j=1,size do 
      local x = i 
      local z = j
      local y =  math.random(0,255)
      local vec = {x,y,z}
      table.insert(tl, vec )
    end 
end 

for i=1,size do 
  for j=1,size do 
    local id2 = (i-1)*size + j
    local id1 = (i-1)*size + j
    local vec2 = tl[id2]
    local vec1 = tl[id1]

    local vec = {0,0,0} 
    vec[1]  = vec1[2]*vec2[3] - vec1[3]*vec2[2]
    vec[2]  = vec1[3]*vec2[1] - vec1[1]*vec2[3]
    vec[3]  = vec1[1]*vec2[2] - vec1[2]*vec2[1]
    --print( tl[id][1]..' '..tl[id][2]..' '..tl[id][3] )
  end 
end 

--]]

-- 回收测试,主动回收
collectgarbage "collect"

print("labs：userdata,calculate ok")
