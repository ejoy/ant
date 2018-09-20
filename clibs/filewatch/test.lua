local fw = require 'filewatch'

local dir = './'
local name = 'test'

--[[
    f  监视文件变化，创建/删除/重命名
    d  监视目录变化，创建/删除/重命名
    t  监视文件和目录修改时间、创建时间的变化
    s  是否监视子目录
]]
local watch = assert(fw.add(dir .. name, 'fdts'))

--[[
    watch A目录，如果A目标被删除，是不会收到通知的，所以需要watch A目录的父目录。
    此外A目录被删后，又被重新创建，这时需要重新watch一次A目录。
]]
local guard = assert(fw.add(dir, 'd'))

while true do
    --[[
        type有五种
            create      创建
            delete      删除
            modify      修改
            rename from 重命名（旧的名字）
            rename to   重命名（新的名字）
    ]]
    local id, type, path = fw.select()
    if id then
        if id == watch then
            print(type, path)
        elseif id == guard and path == name then
            if watch and (type == 'delete' or type == 'rename from') then
                print('[watch stop]')
                fw.remove(watch)
                watch = nil
            elseif not watch and (type == 'create' or type == 'rename to') then
                print('[watch start]')
                watch = assert(fw.add(dir .. name, 'fdts'))
            end
        end
    end
    --sleep(100)
end
