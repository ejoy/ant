local hub = require "hub"
local thread = require "thread"
local connect = {}

local CONNECT_CHANNEL = "_HUB_CONNECT_CHANNEL"

local MSG_TYPE = {
    CALL = 1,
    RESPONSE = 2,
}

function connect:_init()
    self._response_handle_tbl = {}
    self._session_tbl = {}
    self._session_id = 1
    hub.subscibe_mult(CONNECT_CHANNEL,self._on_message_receive,self)
end

function connect:_gen_session_id()
    local id = self._session_id
    self._session_id = self._session_id + 1
    return id
end

function connect:_on_message_receive(msg_pack_list)
    for _,msg_pack in ipairs(msg_pack_list) do
        local proxy_name,session_id,message,msg_type = self:_unpack_message(msg_pack)
        self:_dispatch_message(proxy_name,session_id,message,msg_type)
    end
end

function connect:_dispatch_message(proxy_name,session_id,message,msg_type)
    if msg_type == MSG_TYPE.CALL then --exec handle and then response
        local handle = self._response_handle_tbl[proxy_name]
        if not handle then
            print("not handle for proxy:",proxy_name)
        else
            local data = handle(message)
            local msg_pack = self:_pack_message(proxy_name,session_id,data,MSG_TYPE.RESPONSE)
            hub.publish( CONNECT_CHANNEL,msg_pack)
        end
    else -- response back,not need to response again
        local session_item = self._session_tbl[session_id]
        assert(session_item,string.format("recive response but can't find session:%d,proxy:%s",session_id,proxy_name))
        local handle = session_item.handle
        self._session_tbl[session_id] = nil
        if handle then
            handle(message)
        end
    end
end

function connect:_pack_message(proxy_name,session_id,message,msg_type)
    local tbl = {proxy = proxy_name,session_id=session_id,data = message,msg_type=msg_type}
    -- local packed = thread.pack(tbl)
    return tbl
end

function connect:_unpack_message(msg_pack)
    -- local unpacked = thread.unpack(msg_pack)
    local unpacked = msg_pack
    local proxy_name = unpacked.proxy
    local session_id = unpacked.session_id
    local data = unpacked.data
    local msg_type = unpacked.msg_type
    assert(unpacked and proxy_name and session_id)
    return proxy_name,session_id,data,msg_type
end

function connect:call(proxy_name,data,cb)
    assert(proxy_name and data,"illegal argument")
    local session_id = self:_gen_session_id()
    local session_item = {}
    session_item.data = xxx
    if cb then
        session_item.handle = cb
    end
    self._session_tbl[session_id] = session_item
    local msg_pack = self:_pack_message(proxy_name,session_id,data,MSG_TYPE.CALL)
    hub.publish( CONNECT_CHANNEL,msg_pack )
end

--cb_fun:return data or nil
--cb_target:can be nil
function connect:listen(proxy_name,cb_fun,cb_target)
    assert(proxy_name and cb_fun,"illegal argument")
    assert( not self._response_handle_tbl[proxy_name],"the proxy already binded:"..proxy_name)
    local handle = nil
    if cb_target then
        local fun = function(...)
            return cb_fun(cb_target,...)
        end
        handle = fun
    else
        handle = cb_fun
    end
    self._response_handle_tbl[proxy_name] = handle
end

local function new()
    local ins = setmetatable({},{__index = connect})
    ins:_init()
    return ins
end

return {
    new = new
}
-- function game_hub.

