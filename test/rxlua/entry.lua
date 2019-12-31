
local rx = import_package "ant.rxlua".Rx
local Rx = rx
local RxBus = import_package "ant.rxlua".RxBus
-- log.info_a(rx)
function rx.Observable:dump(name, formatter)
  name = name and (name .. ' ') or ''
  formatter = formatter or tostring

  local onNext = function(...) print(name .. 'onNext: ',...) end
  local onError = function(e) print(name .. 'onError: ' .. e) end
  local onCompleted = function() print(name .. 'onCompleted') end

  return self:subscribe(onNext, onError, onCompleted)
end

function gen_print(tag)
    return function(...)
        print(tag,...)
    end
end
function gen_error(tag)
    return function(...)
        print("error",tag,...)
    end
end
print("------------------test Subject------------------------")

do
    local subject = rx.Subject.create()

    function create_listener(name)
        local onNext = function(...)
            log.info_a(name,"OnNext",...)
        end
        local onError = function(...) 
            log.info_a(name,"onError",...)
        end
        local onCompleted = function(...)
            log.info_a(name,"onCompleted",...)
        end
        return onNext,onError,onCompleted
    end

    subject:subscribe(create_listener("listener1"))
    subject:subscribe(create_listener("listener2"))
    subject:subscribe(create_listener("listener3"))

    subject:onNext("onNext_1")
    subject:onNext("onNext_2")

    subject:onCompleted()
end

print("------------------test BehaviorSubject------------------------")
do

    local subject = rx.BehaviorSubject.create()

    function create_listener(name)
        local onNext = function(...)
            log.info_a(name,"OnNext",...)
        end
        local onError = function(...)
            log.info_a(name,"onError",...)
        end
        local onCompleted = function(...)
            log.info_a(name,"onCompleted",...)
        end
        return onNext,onError,onCompleted
    end

    subject:subscribe(create_listener("listener1"))
    subject:subscribe(create_listener("listener2"))
    subject:subscribe(create_listener("listener3"))

    subject:onNext("onNext_1")
    log(subject:getValue())
    subject:onNext("onNext_2")
    log(subject:getValue())
    subject:onCompleted()
end

print("------------------test concat-----------------------------")
do
    local Rx = rx

    local first = Rx.Observable.fromRange(3)
    local second = Rx.Observable.fromRange(4, 6)
    local third = Rx.Observable.fromRange(7, 11, 2)

    first:concat(second, third):dump('concat')

    print('Equivalent to:')

    Rx.Observable.concat(first, second, third):dump('concat')

end

print("------------------test filter&compact-----------------------------")
do
    local Rx = rx
    local subject = rx.Subject.create()
    local filter = subject:filter(function(a,b)
        return a and a%2 == 0
    end)
    local compact = subject:compact()
    subject:dump('subject')
    filter:dump('filter')
    compact:dump('compact')
    subject:onNext(1,2,3)
    print("-")
    subject:onNext(2,3)
    print("-")
    subject:onNext(nil,2,3)
    print("-")
    subject:onNext(2,3,4,5)
    print("-")
    subject:onNext(3,4,5)
    print("-")

    subject:onNext(4,5)
    print("-")

end

print("------------------test map-----------------------------")
do
    local Rx = rx
    local subject = rx.Subject.create()
    local map = subject:map(function(a)
        return a* 100
    end)
    subject()
end

print("------------------test flatten-----------------------------")
do
    local Rx = rx
    local produce_1 = rx.Subject.create()
    local produce_2 = rx.Subject.create()
    local subject = rx.Subject.create()
    local flatten = subject:flatten()
    subject:dump('subject')
    flatten:dump('flatten')
    subject:onNext(produce_1)
    subject:onNext(produce_2)
    for i = 1,5 do
        produce_1:onNext(i)
        produce_2:onNext(i+100)
    end
end

print("------------------test flatMap-----------------------------")
do
    local Rx = rx
    local observable = Rx.Observable.fromRange(3):flatMap(function(i)
      return Rx.Observable.fromRange(i, 3)
    end)
    observable:dump('flatMap')
end

print("------------------test switch-----------------------------")
do
    local Rx = rx
    local observable = Rx.Observable.fromRange(3):flatMap(function(i)
      return Rx.Observable.fromRange(i, 3)
    end)
    observable:dump('flatMap')
end

print("------------------test tap-----------------------------")
do
    local Rx = rx
    local observable = Rx.Subject.create()
    local tap = observable:tap(gen_print("tag11"))
    observable:subscribe(gen_print("tag12"))
    observable:subscribe(gen_print("tag13"))

    tap:subscribe(gen_print("tag4"))
    tap:subscribe(gen_print("tag5"))

    observable:onNext(1)
    observable:onNext(2)
    observable:onNext(3)

end

print("-------------------------------------------------------")
do
    local Rx = rx
    local Observable = Rx.Observable
    local Subscription = Rx.Subscription

    local subject = Rx.Subject.create()
    local frame_ob = Rx.Subject.create()
    local new = subject:frame(frame_ob)
    new:subscribe(gen_print("++++++"))
    frame_ob:subscribe(gen_print("------"))
    -- subject:subscribe(gen_print("subject"))
    frame_ob:onNext()
    subject:onNext("s1")
    frame_ob:onNext()

    subject:onNext("s2")
    subject:onNext("s3")
    frame_ob:onNext()

    subject:onNext("s4")
    subject:onNext("s5")
    frame_ob:onNext()

end

print("-----------------------------test FramedSubject--------------------------")
do
    local Rx = rx
    local FramedSubject = Rx.FramedSubject
    local frame_ob = Rx.Subject.create()
    local fs = FramedSubject.create(frame_ob)
    fs:subscribe(gen_print("fs----"))
    frame_ob:subscribe(gen_print("frame------"))

    frame_ob:onNext(0)
    fs:onNext(1111)
    frame_ob:onNext(1)
    fs:onNext(222221)
    fs:onNext(222222)

    frame_ob:onNext(2)
    fs:onNext(444444)
    fs:onNext(435555)
    frame_ob:onNext(4)
    fs:onNext(66666)
    fs:onNext(67777)
    frame_ob:onNext(6)
end

print("-----------------------------test RxBus simple--------------------------")
do
    local frame_ob = Rx.Subject.create()
    frame_ob:subscribe(gen_print("frame------"))
    RxBus.init(frame_ob)
    local subject1 = RxBus.get_subject("test1")
    local ob1 = RxBus.get_observable("test1")
    ob1:subscribe(gen_print("          ob1:"))
    subject1:onNext(11)
    subject1:onNext(12)
    frame_ob:onNext(1)

    subject1:onNext(21)
    subject1:onNext(22)
    frame_ob:onNext(2)

end

print("-----------------------------test RxBus ob--------------------------")
do
    local frame_ob = Rx.Subject.create()
    frame_ob:subscribe(gen_print("frame------"))
    RxBus.init(frame_ob)
    local subject1 = RxBus.get_subject("subject2")

    local ob1 = subject1:map(function(a)
        return a+10000
    end)
    -- ob1:subscribe(gen_print("  listener map1:"))
    -- log.info_a(ob1)
    --subscribe before register
    local ob1_1= RxBus.get_observable("test_ob")
    ob1_1:subscribe(gen_print("  listener map1_1:"))
    RxBus.register_observable("test_ob",ob1)
    local listener1 = RxBus.get_observable("subject2")
    listener1:subscribe(gen_print("          listener1:"))
    -- local ob1_1= RxBus.get_observable("test_ob")
    -- log.info_a(ob1_1)

    subject1:onNext(11)
    subject1:onNext(12)
    frame_ob:onNext(1)

    subject1:onNext(21)
    subject1:onNext(22)
    frame_ob:onNext(2)
end

print("-----------------------------test RxBus error--------------------------")
do
    local frame_ob = Rx.Subject.create()
    frame_ob:subscribe(gen_print("frame------"))
    RxBus.init(frame_ob,true)
    local subject1 = RxBus.get_subject("subject2")

    local ob1 = subject1:map(function(a)
        return a+10000
    end)
    -- ob1:subscribe(gen_print("  listener map1:"))
    -- log.info_a(ob1)
    --subscribe before register
    local ob1_1= RxBus.get_observable("test_ob")
    ob1_1:subscribe(gen_print("  listener map1_1:"))
    RxBus.register_observable("test_ob",ob1)
    local listener1 = RxBus.get_observable("subject2")
    listener1:subscribe(gen_print("    listener1:"))
    -- local ob1_1= RxBus.get_observable("test_ob")
    -- log.info_a(ob1_1)

    subject1:onNext(11)
    subject1:onNext(12)
    frame_ob:onNext(1)
    ob1_1= RxBus.get_observable("test_ob")
    ob1_1:subscribe(function()
        print(0)
        error("asd")
    end,gen_error("ob1_1"))

    subject1:onNext(21)
    subject1:onNext(22)
    frame_ob:onNext(2)
end





