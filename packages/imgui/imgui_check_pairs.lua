
local log = print

--================simple stack start=================
local stack_top = 0
local stack = {}
local function push(item)
    stack_top = stack_top + 1
    stack[stack_top] = item
end
local function pop()
    local value = stack[stack_top]
    stack_top = stack_top - 1
    return value
end
--
local function is_top(item)
    return( item == stack[stack_top])
end
local function find_topest(item)
    for i = stack_top,1,-1 do
        if item == stack[i] then
            return i
        end
    end
    return nil
end
--================simple stack end===================


--wait for init
local PureEndFunTbl = {}
local EndFunNameTbl = {}

local ReturnType = {
    NoReturn = 0,       --Has no return,always need an EndXXX
    WhenReturnTrue = 1,    --Need an EndXXX if BeginXXX return true
    IgnoreReturn = 2,   --Has return,but always need an EndXXX
}

--id 101~
local pairs_map_imgui = {
    {ReturnType.NoReturn,"begin_frame", "end_frame"}, -- 100 --type 0
}
--id from 201
local pairs_map_windows = {
    {ReturnType.IgnoreReturn,"Begin","End",}, -- 201 --type 2
    {ReturnType.IgnoreReturn,"BeginChild","EndChild",},-- 202 type 2
    {ReturnType.WhenReturnTrue,"BeginTabBar","EndTabBar",}, -- --type1
    {ReturnType.WhenReturnTrue,"BeginTabItem","EndTabItem",}, -- type1
    {
        ReturnType.WhenReturnTrue,
        "BeginPopup",
        "BeginPopupContextItem",
        "BeginPopupContextWindow",
        "BeginPopupContextVoid",
        "BeginPopupModal",
        "EndPopup",
    }, --type1
}
--id from 301
local pairs_map_widget = {
    {ReturnType.WhenReturnTrue,"BeginCombo","EndCombo"}, -- 301 --type1
    {ReturnType.NoReturn,"BeginTooltip","EndTooltip"}, --302  --type 0
    {ReturnType.WhenReturnTrue,"BeginMainMenuBar","EndMainMenuBar"}, --type 1
    {ReturnType.WhenReturnTrue,"BeginMenu","EndMenu"}, --type1
    {ReturnType.WhenReturnTrue,"BeginListBox","BeginListBoxN","EndListBox",}, --type1
    {ReturnType.NoReturn,"BeginGroup","EndGroup",}, --type 0
    {ReturnType.WhenReturnTrue,"BeginMenuBar","EndMenuBar"}, --type1
    {ReturnType.WhenReturnTrue,"TreeNode","TreePop"}, --type1
    {ReturnType.WhenReturnTrue,"BeginDragDropSource","EndDragDropSource"}, --type1
    {ReturnType.WhenReturnTrue,"BeginDragDropTarget","EndDragDropTarget"}, --type1
}

local function pop_until_idx(idx)
    local top = pop()
    while top ~= idx do
        --todo call top and alter
        local fname = EndFunNameTbl[top]
        log(string.format("[ERROR]:Forget to call %s,call it automaticly",fname))
        local temp_ef =  PureEndFunTbl[top]
        temp_ef()
        if stack_top <= 0 then
            break
        end
        top = pop()
    end
end


--special
local function wrap_begin_frame(bf,idx)
    return function(...)
        if stack_top ~= 0 then
            log("[Fatal Error]:call begin_frame twice before end_frame! stack_top:"..stack_top)
            pop_until_idx(-1) -- pop to empty
        end
        -- assert( stack_top == 0, "[Fatal Error]:call begin_frame twice before end_frame! stack_top:"..stack_top)
        push(idx)
        return bf(...)
    end
end

local function wrap_end_frame(ef,idx)
    return function(...)
        if is_top(idx) then
            pop(idx)
            return ef(...)
        else
            if find_topest(idx) then
                pop_until_idx(idx)
                return ef(...)
            else
                --ef will be ignore
                log("[Error]:call end_frame without begin_frame,end_frame ignored")
            end
        end
    end
end


--common
local wrap_begin_type_no_return = function(bf,idx)
    return function(...)
        push(idx)
        return bf(...)
    end
end
local wrap_begin_type_when_return_true = function(bf,idx)
    return function(...)
        local ret = table.pack(bf(...))
        if ret[1] then
            push(idx)
        end
        return table.unpack(ret)
    end
end
local wrap_begin_type_ignore_return = function(bf,idx)
    return function(...)
        push(idx)
        return bf(...)
    end
end
local wrap_end = function(ef,idx)
    return function(...)
        if is_top(idx) then
            pop(idx)
            return ef(...)
        else
            if find_topest(idx) then
                pop_until_idx(idx)
                return ef(...)
            else
                local fname = EndFunNameTbl[idx]
                --ef will be ignore
                log(string.format("[Error]:call %s without begin_xxx pairs,%s ignored",fname,fname))
            end
        end
    end
end


--cache EndFunNameTbl and PureEndFunTbl
local function init(imgui)
    local cfgs = {
        [100] = {imgui,pairs_map_imgui,},
        [200] = {imgui.windows,pairs_map_windows,},
        [300] = {imgui.widget,pairs_map_widget,},
    }
    for start_idx,cfg in pairs(cfgs) do
        local fun_head =  cfg[1]
        local pairs_map =  cfg[2]
        for i,pair in ipairs(pairs_map) do
            local idx = start_idx + i
            local ef_name = pair[#pair]
            EndFunNameTbl[idx] = ef_name
            PureEndFunTbl[idx] = fun_head[ef_name]
        end
    end
end

local function wrap_pairs(imgui)
    --cache EndFunNameTbl and PureEndFunTbl
    init(imgui)

    local cur_idx = 101
    local cur_item = pairs_map_imgui[1]
    imgui[cur_item[2]] = wrap_begin_frame(imgui[cur_item[2]],cur_idx)
    imgui[cur_item[3]] = wrap_end_frame(imgui[cur_item[3]],cur_idx)

    local cfgs ={
        [200] = {imgui.windows,pairs_map_windows,},
        [300] = {imgui.widget,pairs_map_widget,}
    }
    local begin_fun_map = {
        [ReturnType.NoReturn] = wrap_begin_type_no_return,
        [ReturnType.WhenReturnTrue] = wrap_begin_type_when_return_true,
        [ReturnType.IgnoreReturn] = wrap_begin_type_ignore_return,

    }
    for start_idx,cfg in pairs(cfgs) do
        local fun_head =  cfg[1]
        local pairs_map =  cfg[2]
        for i,pair in ipairs(pairs_map) do
            local idx = start_idx + i
            local return_type = pair[1]
            local begin_fun_wrap = begin_fun_map[return_type]
            local pair_size = #pair
            for i = 2,pair_size - 1 do
                fun_head[pair[i]] = begin_fun_wrap(fun_head[pair[i]],idx)
            end
            fun_head[pair[pair_size]] = wrap_end(fun_head[pair[pair_size]],idx)
        end
    end
end

return wrap_pairs