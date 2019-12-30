local dbgutil = import_package "ant.editor".debugutil
local Rx = require "rx"
local RxBus = require "rxbus"
local extendfunc = require "extendrx"
extendfunc(Rx)
local dbgutil = import_package "ant.editor".debugutil
Rx.util.tryWithObserver = function(observer, fn, ...)
  local success, result = dbgutil.try(fn, ...)
  if not success then
    observer:onError(result)
  end
  return success, result
end

local update_ob = Rx.Subject.create()
RxBus.init(update_ob)
local update = function(delta)
    -- update_ob:onNext(delta)
    dbgutil.try(update_ob.onNext,update_ob,delta)
end

return {
    Rx = Rx,
    update = update,
    RxBus = require "rxbus"
}