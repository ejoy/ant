local math3d = require "math3d"
local base = require "widget.base_property_widget"

local function quat2euler(quat_tbl)
    assert(#quat_tbl == 4,"quatnion has not 4 elements!")
    local euler_tbl =  math3d.totable(
        math3d.quat2euler(
            math3d.quaternion(quat_tbl)
            )
        )
    euler_tbl[4] = nil
    return euler_tbl
end



local function euler2quat(euler_tbl)
    assert( euler_tbl[4] == nil,"euler must has 3 elements only")
    return math3d.totable(math3d.quaternion(euler_tbl))
end

local function mult_quat2euler(quat_tbls)
    local eulers = {}
    for i,quat_tbl in ipairs(quat_tbls) do
        eulers[i] = quat2euler(quat_tbl)
    end
    return eulers
end

local function mult_euler2quat(euler_tbls)
    local quats = {}
    for i,euler_tbl in ipairs(euler_tbls) do
        quats[i] = euler2quat(euler_tbl)
    end
    return quats
end


local function quaternion(ui_cache,name,value,cfg)
    local euler_tbl = quat2euler(value)
    local change,new_v,active = base.single.vector(ui_cache,name,euler_tbl,cfg)
    if change then
        assert(new_v)
        new_v = euler2quat(new_v)
    else
        new_v = nil
    end
    return change,new_v,active
end

local function mult_quaternion(ui_cache,name,values,cfg)
    local euler_tbls = mult_quat2euler(values)
    local change,new_vs,active = base.mult.vector(ui_cache,name,euler_tbls,cfg)
    if new_vs then
        new_vs = mult_euler2quat(new_vs)
    end
    return change,new_vs,active
end

local widgets = {
    single = {
        quaternion = quaternion,
    },
    mult = {
        quaternion = mult_quaternion,
    },
    --像Vector这种由多个元素组成的，多选编辑器的时候，只会改变其中某一项
--所以需要返回一个数组,比如修改了y值，需要返回{{x1,y,z1},{x2,y,z2},{x3,y,z3},...}
    WillReturnList = {
        quaternion = true,
    }

}

return widgets