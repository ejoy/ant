
local log_error = (log and log.error) or print

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

local cur_style_dict_index = 1
local style_dict = {{}}


--wait for init
local PureEndFunTbl = {}
local EndFunNameTbl = {}

local ReturnType = {
    Dummy = 3,
    NoReturn = 0,       --Has no return,always need an EndXXX
    WhenReturnTrue = 1,    --Need an EndXXX if BeginXXX return true
    IgnoreReturn = 2,   --Has return,but always need an EndXXX
}

--id 101~
local pairs_map_imgui = {
    {101,ReturnType.NoReturn,"begin_frame", "end_frame"}, -- 100 --type 0
}
--id from 201 
--{type,check_push_and_pop,...}
local pairs_map_windows = {
    {201,ReturnType.IgnoreReturn,true,"Begin","End",}, -- 201 --type 2
    {202,ReturnType.IgnoreReturn,false,"BeginChild","EndChild",},-- 202 type 2
    {203,ReturnType.WhenReturnTrue,false,"BeginTabBar","EndTabBar",}, -- --type1
    {204,ReturnType.WhenReturnTrue,false,"BeginTabItem","EndTabItem",}, -- type1
    {
        205,
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
--{type,check_push_and_pop,...}
local pairs_map_widget = {
    {301,ReturnType.WhenReturnTrue,false,"BeginCombo","EndCombo"}, -- 301 --type1
    {302,ReturnType.NoReturn,false,"BeginTooltip","EndTooltip"}, --302  --type 0
    {303,ReturnType.WhenReturnTrue,false,"BeginMainMenuBar","EndMainMenuBar"}, --type 1
    {304,ReturnType.WhenReturnTrue,false,"BeginMenu","EndMenu"}, --type1
    {305,ReturnType.WhenReturnTrue,false,"BeginListBox","BeginListBoxN","EndListBox",}, --type1
    {306,ReturnType.NoReturn,false,"BeginGroup","EndGroup",}, --type 0
    {307,ReturnType.WhenReturnTrue,false,"BeginMenuBar","EndMenuBar"}, --type1
    {308,ReturnType.WhenReturnTrue,false,"TreeNode","TreePop"}, --type1
    {308,ReturnType.NoReturn,false,"TreePush","TreePop"}, --type1
    {309,ReturnType.WhenReturnTrue,false,"BeginDragDropSource","EndDragDropSource"}, --type1
    {310,ReturnType.WhenReturnTrue,false,"BeginDragDropTarget","EndDragDropTarget"}, --type1
}

--id from 401
local pairs_map_style = {
    {401,ReturnType.Dummy,"PushStyleColor","PopStyleColor"},
    {402,ReturnType.Dummy,"PushStyleVar","PopStyleVar"},
}

local function pop_until_idx(idx)
    local top = pop()
    while top ~= idx do
        --todo call top and alter
        local fname = EndFunNameTbl[top]
        log_error(string.format("Forget to call %s,call it automaticly",fname))
        local temp_ef =  PureEndFunTbl[top]
        temp_ef()
        if stack_top <= 0 then
            break
        end
        top = pop()
    end
end

local check_and_pop_style = function()
    local cur_style_dict = style_dict[cur_style_dict_index]
    for style_id,num in pairs(cur_style_dict) do
        if num > 0 then
            local ef_name = EndFunNameTbl[style_id]
            local temp_ef =  PureEndFunTbl[style_id]
            log_error(string.format("Forget to %s,call it automaticly,stack size:%d",ef_name,num))
            temp_ef(num)
            cur_style_dict[style_id] = 0
        end
    end
end


--special
local function wrap_begin_frame(bf,idx)
    return function(...)
        if stack_top ~= 0 then
            log_error("call begin_frame twice before end_frame! stack_top:"..stack_top)
            cur_style_dict_index = 1
            check_and_pop_style()
            pop_until_idx(-1) -- pop to empty
        end
        -- assert( stack_top == 0, "[Fatal Error]:call begin_frame twice before end_frame! stack_top:"..stack_top)
        push(idx)
        return bf(...)
    end
end

local function wrap_end_frame(ef,idx)
    return function(...)
        cur_style_dict_index = 1
        check_and_pop_style()
        if is_top(idx) then
            pop(idx)
            return ef(...)
        else
            if find_topest(idx) then
                pop_until_idx(idx)
                return ef(...)
            else
                --ef will be ignore
                log_error("call end_frame without begin_frame,end_frame ignored")
            end
        end
    end
end

local function wrap_push_style(bf,idx)
    return function(...)
        local cur_style_dict = style_dict[cur_style_dict_index]
        cur_style_dict[idx] = cur_style_dict[idx] and (cur_style_dict[idx] + 1) or 1
        -- log("push",401,style_dict[401],402,style_dict[402])
        return bf(...)
    end
end

local function wrap_pop_style(ef,idx)
    return function(num)
        local cur_style_dict = style_dict[cur_style_dict_index]
        num = num or 1
        cur_style_dict[idx] = (cur_style_dict[idx] or 0) - num
        -- log("pop",401,cur_style_dict[401],402,cur_style_dict[402])
        if cur_style_dict[idx] < 0 then
            local name = EndFunNameTbl[idx]
            log_error("call style function mismatch stack size<0:",name)
        end
        return ef(num)
    end
end

local push_style_dict = function()
    cur_style_dict_index = cur_style_dict_index + 1
    style_dict[cur_style_dict_index] = {}
end

--common
local wrap_begin_type_no_return = function(bf,idx,is_style_region)
    return function(...)
        if is_style_region then
            push_style_dict()
        end 
        push(idx)
        return bf(...)
    end
end
local wrap_begin_type_when_return_true = function(bf,idx,is_style_region)
    return function(...)

        local ret = table.pack(bf(...))
        if ret[1] then
            if is_style_region then
                push_style_dict()
            end 
            push(idx)
        end
        return table.unpack(ret)
    end
end
local wrap_begin_type_ignore_return = function(bf,idx,is_style_region)
    return function(...)
        if is_style_region then
            push_style_dict()
        end 
        push(idx)
        return bf(...)
    end
end
local wrap_end = function(ef,idx,is_style_region)
    return function(...)
        
        if is_top(idx) then
            if is_style_region then
                check_and_pop_style()
                cur_style_dict_index = cur_style_dict_index - 1
            end
            pop(idx)
            return ef(...)
        else
            if find_topest(idx) then
                pop_until_idx(idx)
                if is_style_region then
                    check_and_pop_style()
                    cur_style_dict_index = cur_style_dict_index - 1
                end
                return ef(...)
            else
                local fname = EndFunNameTbl[idx]
                --ef will be ignore
                log_error(string.format("call %s without begin_xxx pairs,%s ignored",fname,fname))
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
        [400] = {imgui.windows,pairs_map_style,},
    }
    for _,cfg in pairs(cfgs) do
        local fun_head =  cfg[1]
        local pairs_map =  cfg[2]
        for i,pair in ipairs(pairs_map) do
            local idx = pair[1]
            local ef_name = pair[#pair]
            EndFunNameTbl[idx] = ef_name
            PureEndFunTbl[idx] = fun_head[ef_name]
        end
    end

end

local function wrap_pairs(imgui)
    --cache EndFunNameTbl and PureEndFunTbl
    init(imgui)
    -----------begin/end frame
    local cur_item = pairs_map_imgui[1]
    local cur_idx = cur_item[1]
    imgui[cur_item[3]] = wrap_begin_frame(imgui[cur_item[3]],cur_idx)
    imgui[cur_item[4]] = wrap_end_frame(imgui[cur_item[4]],cur_idx)
    -------------normal beginxxx/endxxx
    local cfgs ={
        [200] = {imgui.windows,pairs_map_windows,},
        [300] = {imgui.widget,pairs_map_widget,}
    }
    local begin_fun_map = {
        [ReturnType.NoReturn] = wrap_begin_type_no_return,
        [ReturnType.WhenReturnTrue] = wrap_begin_type_when_return_true,
        [ReturnType.IgnoreReturn] = wrap_begin_type_ignore_return,

    }
    local wraped = {}
    for _,cfg in pairs(cfgs) do
        local fun_head =  cfg[1]
        local pairs_map =  cfg[2]
        for i,pair in ipairs(pairs_map) do
            local idx = pair[1]
            local return_type = pair[2]
            local is_style_region = pair[3]
            local begin_fun_wrap = begin_fun_map[return_type]
            local pair_size = #pair
            for i = 4,pair_size - 1 do
                if not wraped[pair[i]] then
                    fun_head[pair[i]] = begin_fun_wrap(fun_head[pair[i]],idx,is_style_region)
                    wraped[pair[i]] = true
                end
            end
            if not wraped[pair[pair_size]] then
                fun_head[pair[pair_size]] = wrap_end(fun_head[pair[pair_size]],idx,is_style_region)
                wraped[pair[pair_size]] = true
            end
        end
    end
    --------push/pop style
    local style_cfg = {
        [400] =  {imgui.windows,pairs_map_style},
    }
    for _,cfg in pairs(style_cfg) do
        local fun_head =  cfg[1]
        local pairs_map =  cfg[2]
        for i,ps in ipairs(pairs_map) do
            local idx = ps[1]
            -- style_dict[idx] = 0
            fun_head[ps[3]] = wrap_push_style(fun_head[ps[3]],idx)
            fun_head[ps[4]] = wrap_pop_style(fun_head[ps[4]],idx)
        end
    end
end

return wrap_pairs