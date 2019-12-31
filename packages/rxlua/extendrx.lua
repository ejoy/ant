local function extend(Rx)
    if Rx.__entended then
        return
    end
    Rx.__entended = true
    local function handler(func,self)
        return function(...)
            return func(self,...)
        end
    end
    Rx.handler = handler
    function Rx.Observable:frame(frame_driver)
        if not frame_driver then
            error("Expected a Observable")
        end
        return Rx.Observable.create(function(observer)
            local buffer = {}
            local subscription_tick,subscription_self
            local function emit()
                if #buffer > 0 then
                    for i = 1,#buffer do
                        local data = buffer[i]
                        observer:onNext(Rx.util.unpack(data))
                    end
                    buffer = {}
                end
            end

            local function onNext(...)
                local values = {...}
                table.insert(buffer, values)
            end

            local function onNextTick(...)
                emit()
            end

            local function onError(message)
                emit()
                return observer:onError(message)
            end

            local function onCompleted()
                emit()
                return observer:onCompleted()
            end
            subscription_tick = frame_driver:subscribe(onNextTick)
            subscription_self = self:subscribe(onNext, onError, onCompleted)
            return Rx.Subscription.create(
                function()
                    subscription_tick:unsubscribe()
                    subscription_self:unsubscribe()
                end)

        end)
    end

    --------------------FramedSubject--------------------------
    local FramedSubject = setmetatable({},Rx.Subject)
    FramedSubject.__index = FramedSubject
    FramedSubject.__tostring = Rx.util.constant("FramedSubject")
    function FramedSubject.create(frame_driver)
        local self = {
            observers = {},
            stopped = false,
            frame_driver = frame_driver,
            frame_ob = nil
        }
        return setmetatable(self, FramedSubject)
    end

    function FramedSubject:frame(frame_driver)
        if self.frame_ob then
            return self.frame_ob
        end
        if not frame_driver then
            error("Expected a Observable")
        end
        return Rx.Observable.create(function(observer)
            local buffer = {}
            local subscription_tick,subscription_self
            local function emit()
                if #buffer > 0 then
                    for i = 1,#buffer do
                        local data = buffer[i]
                        observer:onNext(Rx.util.unpack(data))
                    end
                    buffer = {}
                end
            end

            local function onNext(...)
                local values = {...}
                table.insert(buffer, values)
            end

            local function onNextTick(...)
                emit()
            end

            local function onError(message)
                emit()
                return observer:onError(message)
            end

            local function onCompleted()
                emit()
                return observer:onCompleted()
            end
            subscription_tick = frame_driver:subscribe(onNextTick)
            subscription_self = Rx.Subject.subscribe(self,onNext, onError, onCompleted)
            return Rx.Subscription.create(
                function()
                    subscription_tick:unsubscribe()
                    subscription_self:unsubscribe()
                end)

        end)
    end

    function FramedSubject:subscribe(onNext, onError, onCompleted)
        if self.frame_ob == nil then
            self.frame_ob = self:frame(self.frame_driver)
        end
        return self.frame_ob:subscribe(onNext, onError, onCompleted)
    end

    Rx.FramedSubject = FramedSubject
end

return extend