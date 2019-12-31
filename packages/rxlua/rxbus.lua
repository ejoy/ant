local Rx = require "rx"
local RxBus = {}

local subject_tbl = {}
RxBus.subject_tbl = subject_tbl
local observable_tbl = {}
RxBus.observable_tbl = observable_tbl
local pipe_tbl = {}
RxBus.pipe_tbl = pipe_tbl
RxBus.frame_observable = nil


function RxBus.init(frame_observable,reset)
    RxBus.frame_observable = frame_observable
    if reset then
        subject_tbl = {}
        RxBus.subject_tbl = subject_tbl
        observable_tbl = {}
        RxBus.observable_tbl = observable_tbl
        pipe_tbl = {}
        RxBus.pipe_tbl = pipe_tbl
    end
end

 
function RxBus._create_subject(event_key)
    assert(RxBus.frame_observable)
    local subject = Rx.FramedSubject.create(RxBus.frame_observable)
    subject_tbl[event_key] = subject
    observable_tbl[event_key] = subject
    --todo pipe
    RxBus._try_bind_pipe_to_ob(subject,event_key)
    return subject
end

function RxBus._create_pipe_observable(event_key)
    local subject = Rx.Subject.create()
    local pipe = subject:flatten()
    pipe.subject = subject
    pipe_tbl[event_key] = pipe
    return pipe
end

local function dont_subscribe()
    error("don't cache the return of get_observable,reget when you use")
end

function RxBus._try_bind_pipe_to_ob(ob,event_key)
    local pipe =  pipe_tbl[event_key]
    if pipe then
        local subject = pipe.subject
        subject:onNext(ob)
        pipe.subscribe = dont_subscribe
        return true
    end
    return false
end

function RxBus._raw_get_observable(event_key)
    local ob = observable_tbl[event_key] or pipe_tbl[event_key]
    return ob
end  

function RxBus.register_observable(event_key,ob)
    assert(event_key)
    assert(not RxBus.observable_tbl[event_key])
    assert(not RxBus.subject_tbl[event_key])
    observable_tbl[event_key] = ob
    subject_tbl[event_key] = ob
    --todo pipe
    RxBus._try_bind_pipe_to_ob(ob,event_key)
end

--return Subject to be listened
function RxBus.get_subject(event_key)
    assert(event_key)
    local subject = subject_tbl[event_key]
    if not subject then
        subject = RxBus._create_subject(event_key)
    end
    return subject
end

--return Observable to be listened
function RxBus.get_observable(event_key)
    assert(event_key)
    local ob = RxBus._raw_get_observable(event_key)
    if not ob then
        ob = RxBus._create_pipe_observable(event_key)
    end
    return ob

end

return RxBus