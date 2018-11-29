package.cpath = package.cpath:gsub("%.so", ".dll")

local fw = require 'filewatch'

local path = './test'

local watch = assert(fw.add(path))

while true do
    --[[
        type有五种
            error       错误
            create      创建
            delete      删除
            modify      修改
            rename      重命名
    ]]
    local type, path = fw.select()
    if type then
        print(type, path)
    end
    --sleep(100)
end
