-- RxLua v0.0.3
-- https://github.com/bjornbytes/rxlua
-- MIT License

local util = {}

util.pack = table.pack or function(...) return { n = select('#', ...), ... } end
util.unpack = table.unpack or unpack
util.eq = function(x, y) return x == y end
util.noop = function() end
util.identity = function(x) return x end
util.constant = function(x) return function() return x end end
util.isa = function(object, class)
  return type(object) == 'table' and getmetatable(object).__index == class
end
util.tryWithObserver = function(observer, fn, ...)
  local success, result = pcall(fn, ...)
  if not success then
    observer:onError(result)
  end
  return success, result
end

--- @class Subscription
-- @description A handle representing the link between an Observer and an Observable, as well as any
-- work required to clean up after the Observable completes or the Observer unsubscribes.
local Subscription = {}
Subscription.__index = Subscription
Subscription.__tostring = util.constant('Subscription')

--- Creates a new Subscription.
-- @arg {function=} action - The action to run when the subscription is unsubscribed. It will only
--                           be run once.
-- @returns {Subscription}
function Subscription.create(action)
  local self = {
    action = action or util.noop,
    unsubscribed = false
  }

  return setmetatable(self, Subscription)
end

--- Unsubscribes the subscription, performing any necessary cleanup work.
function Subscription:unsubscribe()
  if self.unsubscribed then return end
  self.action(self)
  self.unsubscribed = true
end

--- @class Observer
-- @description Observers are simple objects that receive values from Observables.
local Observer = {}
Observer.__index = Observer
Observer.__tostring = util.constant('Observer')

--- Creates a new Observer.
-- @arg {function=} onNext - Called when the Observable produces a value.
-- @arg {function=} onError - Called when the Observable terminates due to an error.
-- @arg {function=} onCompleted - Called when the Observable completes normally.
-- @returns {Observer}
function Observer.create(onNext, onError, onCompleted)
  local self = {
    _onNext = onNext or util.noop,
    _onError = onError or error,
    _onCompleted = onCompleted or util.noop,
    stopped = false
  }

  return setmetatable(self, Observer)
end

--- Pushes zero or more values to the Observer.
-- @arg {*...} values
function Observer:onNext(...)
  if not self.stopped then
    self._onNext(...)
  end
end

--- Notify the Observer that an error has occurred.
-- @arg {string=} message - A string describing what went wrong.
function Observer:onError(message)
  if not self.stopped then
    self.stopped = true
    self._onError(message)
  end
end

--- Notify the Observer that the sequence has completed and will produce no more values.
function Observer:onCompleted()
  if not self.stopped then
    self.stopped = true
    self._onCompleted()
  end
end

--- @class Observable
-- @description Observables push values to Observers.
local Observable = {}
Observable.__index = Observable
Observable.__tostring = util.constant('Observable')

--- Creates a new Observable.
-- @arg {function} subscribe - The subscription function that produces values.
-- @returns {Observable}
function Observable.create(subscribe)
  local self = {
    _subscribe = subscribe
  }

  return setmetatable(self, Observable)
end

--- Shorthand for creating an Observer and passing it to this Observable's subscription function.
-- @arg {function} onNext - Called when the Observable produces a value.
-- @arg {function} onError - Called when the Observable terminates due to an error.
-- @arg {function} onCompleted - Called when the Observable completes normally.
function Observable:subscribe(onNext, onError, onCompleted)
  if type(onNext) == 'table' then
    return self._subscribe(onNext)
  else
    return self._subscribe(Observer.create(onNext, onError, onCompleted))
  end
end

--- Returns an Observable that immediately completes without producing a value.
function Observable.empty()
  return Observable.create(function(observer)
    observer:onCompleted()
  end)
end

--- Returns an Observable that never produces values and never completes.
function Observable.never()
  return Observable.create(function(observer) end)
end

--- Returns an Observable that immediately produces an error.
function Observable.throw(message)
  return Observable.create(function(observer)
    observer:onError(message)
  end)
end

--- Creates an Observable that produces a set of values.
-- @arg {*...} values
-- @returns {Observable}
function Observable.of(...)
  local args = {...}
  local argCount = select('#', ...)
  return Observable.create(function(observer)
    for i = 1, argCount do
      observer:onNext(args[i])
    end

    observer:onCompleted()
  end)
end

--- Creates an Observable that produces a range of values in a manner similar to a Lua for loop.
-- @arg {number} initial - The first value of the range, or the upper limit if no other arguments
--                         are specified.
-- @arg {number=} limit - The second value of the range.
-- @arg {number=1} step - An amount to increment the value by each iteration.
-- @returns {Observable}
function Observable.fromRange(initial, limit, step)
  if not limit and not step then
    initial, limit = 1, initial
  end

  step = step or 1

  return Observable.create(function(observer)
    for i = initial, limit, step do
      observer:onNext(i)
    end

    observer:onCompleted()
  end)
end

--- Creates an Observable that produces values from a table.
-- @arg {table} table - The table used to create the Observable.
-- @arg {function=pairs} iterator - An iterator used to iterate the table, e.g. pairs or ipairs.
-- @arg {boolean} keys - Whether or not to also emit the keys of the table.
-- @returns {Observable}
function Observable.fromTable(t, iterator, keys)
  iterator = iterator or pairs
  return Observable.create(function(observer)
    for key, value in iterator(t) do
      observer:onNext(value, keys and key or nil)
    end

    observer:onCompleted()
  end)
end

--- Creates an Observable that produces values when the specified coroutine yields.
-- @arg {thread|function} fn - A coroutine or function to use to generate values.  Note that if a
--                             coroutine is used, the values it yields will be shared by all
--                             subscribed Observers (influenced by the Scheduler), whereas a new
--                             coroutine will be created for each Observer when a function is used.
-- @returns {Observable}
function Observable.fromCoroutine(fn, scheduler)
  return Observable.create(function(observer)
    local thread = type(fn) == 'function' and coroutine.create(fn) or fn
    return scheduler:schedule(function()
      while not observer.stopped do
        local success, value = coroutine.resume(thread)

        if success then
          observer:onNext(value)
        else
          return observer:onError(value)
        end

        if coroutine.status(thread) == 'dead' then
          return observer:onCompleted()
        end

        coroutine.yield()
      end
    end)
  end)
end

--- Creates an Observable that produces values from a file, line by line.
-- @arg {string} filename - The name of the file used to create the Observable
-- @returns {Observable}
function Observable.fromFileByLine(filename)
  return Observable.create(function(observer)
    local file = io.open(filename, 'r')
    if file then
      file:close()

      for line in io.lines(filename) do
        observer:onNext(line)
      end

      return observer:onCompleted()
    else
      return observer:onError(filename)
    end
  end)
end

--- Creates an Observable that creates a new Observable for each observer using a factory function.
-- @arg {function} factory - A function that returns an Observable.
-- @returns {Observable}
function Observable.defer(fn)
  if not fn or type(fn) ~= 'function' then
    error('Expected a function')
  end

  return setmetatable({
    subscribe = function(_, ...)
      local observable = fn()
      return observable:subscribe(...)
    end
  }, Observable)
end

--- Returns an Observable that repeats a value a specified number of times.
-- @arg {*} value - The value to repeat.
-- @arg {number=} count - The number of times to repeat the value.  If left unspecified, the value
--                        is repeated an infinite number of times.
-- @returns {Observable}
function Observable.replicate(value, count)
  return Observable.create(function(observer)
    while count == nil or count > 0 do
      observer:onNext(value)
      if count then
        count = count - 1
      end
    end
    observer:onCompleted()
  end)
end

--- Subscribes to this Observable and prints values it produces.
-- @arg {string=} name - Prefixes the printed messages with a name.
-- @arg {function=tostring} formatter - A function that formats one or more values to be printed.
function Observable:dump(name, formatter)
  name = name and (name .. ' ') or ''
  formatter = formatter or tostring

  local onNext = function(...) print(name .. 'onNext: ' .. formatter(...)) end
  local onError = function(e) print(name .. 'onError: ' .. e) end
  local onCompleted = function() print(name .. 'onCompleted') end

  return self:subscribe(onNext, onError, onCompleted)
end

--- Determine whether all items emitted by an Observable meet some criteria.
-- @arg {function=identity} predicate - The predicate used to evaluate objects.
function Observable:all(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if not predicate(...) then
          observer:onNext(false)
          observer:onCompleted()
        end
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      observer:onNext(true)
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Given a set of Observables, produces values from only the first one to produce a value.
-- @arg {Observable...} observables
-- @returns {Observable}
function Observable.amb(a, b, ...)
  if not a or not b then return a end

  return Observable.create(function(observer)
    local subscriptionA, subscriptionB

    local function onNextA(...)
      if subscriptionB then subscriptionB:unsubscribe() end
      observer:onNext(...)
    end

    local function onErrorA(e)
      if subscriptionB then subscriptionB:unsubscribe() end
      observer:onError(e)
    end

    local function onCompletedA()
      if subscriptionB then subscriptionB:unsubscribe() end
      observer:onCompleted()
    end

    local function onNextB(...)
      if subscriptionA then subscriptionA:unsubscribe() end
      observer:onNext(...)
    end

    local function onErrorB(e)
      if subscriptionA then subscriptionA:unsubscribe() end
      observer:onError(e)
    end

    local function onCompletedB()
      if subscriptionA then subscriptionA:unsubscribe() end
      observer:onCompleted()
    end

    subscriptionA = a:subscribe(onNextA, onErrorA, onCompletedA)
    subscriptionB = b:subscribe(onNextB, onErrorB, onCompletedB)

    return Subscription.create(function()
      subscriptionA:unsubscribe()
      subscriptionB:unsubscribe()
    end)
  end):amb(...)
end

--- Returns an Observable that produces the average of all values produced by the original.
-- @returns {Observable}
function Observable:average()
  return Observable.create(function(observer)
    local sum, count = 0, 0

    local function onNext(value)
      sum = sum + value
      count = count + 1
    end

    local function onError(e)
      observer:onError(e)
    end

    local function onCompleted()
      if count > 0 then
        observer:onNext(sum / count)
      end

      observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that buffers values from the original and produces them as multiple
-- values.
-- @arg {number} size - The size of the buffer.
function Observable:buffer(size)
  if not size or type(size) ~= 'number' then
    error('Expected a number')
  end

  return Observable.create(function(observer)
    local buffer = {}

    local function emit()
      if #buffer > 0 then
        observer:onNext(util.unpack(buffer))
        buffer = {}
      end
    end

    local function onNext(...)
      local values = {...}
      for i = 1, #values do
        table.insert(buffer, values[i])
        if #buffer >= size then
          emit()
        end
      end
    end

    local function onError(message)
      emit()
      return observer:onError(message)
    end

    local function onCompleted()
      emit()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that intercepts any errors from the previous and replace them with values
-- produced by a new Observable.
-- @arg {function|Observable} handler - An Observable or a function that returns an Observable to
--                                      replace the source Observable in the event of an error.
-- @returns {Observable}
function Observable:catch(handler)
  handler = handler and (type(handler) == 'function' and handler or util.constant(handler))

  return Observable.create(function(observer)
    local subscription

    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(e)
      if not handler then
        return observer:onCompleted()
      end

      local success, _continue = pcall(handler, e)
      if success and _continue then
        if subscription then subscription:unsubscribe() end
        _continue:subscribe(observer)
      else
        observer:onError(success and e or _continue)
      end
    end

    local function onCompleted()
      observer:onCompleted()
    end

    subscription = self:subscribe(onNext, onError, onCompleted)
    return subscription
  end)
end

--- Returns a new Observable that runs a combinator function on the most recent values from a set
-- of Observables whenever any of them produce a new value. The results of the combinator function
-- are produced by the new Observable.
-- @arg {Observable...} observables - One or more Observables to combine.
-- @arg {function} combinator - A function that combines the latest result from each Observable and
--                              returns a single value.
-- @returns {Observable}
function Observable:combineLatest(...)
  local sources = {...}
  local combinator = table.remove(sources)
  if type(combinator) ~= 'function' then
    table.insert(sources, combinator)
    combinator = function(...) return ... end
  end
  table.insert(sources, 1, self)

  return Observable.create(function(observer)
    local latest = {}
    local pending = {util.unpack(sources)}
    local completed = {}
    local subscription = {}

    local function onNext(i)
      return function(value)
        latest[i] = value
        pending[i] = nil

        if not next(pending) then
          util.tryWithObserver(observer, function()
            observer:onNext(combinator(util.unpack(latest)))
          end)
        end
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted(i)
      return function()
        table.insert(completed, i)

        if #completed == #sources then
          observer:onCompleted()
        end
      end
    end

    for i = 1, #sources do
      subscription[i] = sources[i]:subscribe(onNext(i), onError, onCompleted(i))
    end

    return Subscription.create(function ()
      for i = 1, #sources do
        if subscription[i] then subscription[i]:unsubscribe() end
      end
    end)
  end)
end

--- Returns a new Observable that produces the values of the first with falsy values removed.
-- @returns {Observable}
function Observable:compact()
  return self:filter(util.identity)
end

--- Returns a new Observable that produces the values produced by all the specified Observables in
-- the order they are specified.
-- @arg {Observable...} sources - The Observables to concatenate.
-- @returns {Observable}
function Observable:concat(other, ...)
  if not other then return self end

  local others = {...}

  return Observable.create(function(observer)
    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local function chain()
      return other:concat(util.unpack(others)):subscribe(onNext, onError, onCompleted)
    end

    return self:subscribe(onNext, onError, chain)
  end)
end

--- Returns a new Observable that produces a single boolean value representing whether or not the
-- specified value was produced by the original.
-- @arg {*} value - The value to search for.  == is used for equality testing.
-- @returns {Observable}
function Observable:contains(value)
  return Observable.create(function(observer)
    local subscription

    local function onNext(...)
      local args = util.pack(...)

      if #args == 0 and value == nil then
        observer:onNext(true)
        if subscription then subscription:unsubscribe() end
        return observer:onCompleted()
      end

      for i = 1, #args do
        if args[i] == value then
          observer:onNext(true)
          if subscription then subscription:unsubscribe() end
          return observer:onCompleted()
        end
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      observer:onNext(false)
      return observer:onCompleted()
    end

    subscription = self:subscribe(onNext, onError, onCompleted)
    return subscription
  end)
end

--- Returns an Observable that produces a single value representing the number of values produced
-- by the source value that satisfy an optional predicate.
-- @arg {function=} predicate - The predicate used to match values.
function Observable:count(predicate)
  predicate = predicate or util.constant(true)

  return Observable.create(function(observer)
    local count = 0

    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if predicate(...) then
          count = count + 1
        end
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      observer:onNext(count)
      observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new throttled Observable that waits to produce values until a timeout has expired, at
-- which point it produces the latest value from the source Observable.  Whenever the source
-- Observable produces a value, the timeout is reset.
-- @arg {number|function} time - An amount in milliseconds to wait before producing the last value.
-- @arg {Scheduler} scheduler - The scheduler to run the Observable on.
-- @returns {Observable}
function Observable:debounce(time, scheduler)
  time = time or 0

  return Observable.create(function(observer)
    local debounced = {}

    local function wrap(key)
      return function(...)
        local value = util.pack(...)

        if debounced[key] then
          debounced[key]:unsubscribe()
        end

        local values = util.pack(...)

        debounced[key] = scheduler:schedule(function()
          return observer[key](observer, util.unpack(values))
        end, time)
      end
    end

    local subscription = self:subscribe(wrap('onNext'), wrap('onError'), wrap('onCompleted'))

    return Subscription.create(function()
      if subscription then subscription:unsubscribe() end
      for _, timeout in pairs(debounced) do
        timeout:unsubscribe()
      end
    end)
  end)
end

--- Returns a new Observable that produces a default set of items if the source Observable produces
-- no values.
-- @arg {*...} values - Zero or more values to produce if the source completes without emitting
--                      anything.
-- @returns {Observable}
function Observable:defaultIfEmpty(...)
  local defaults = util.pack(...)

  return Observable.create(function(observer)
    local hasValue = false

    local function onNext(...)
      hasValue = true
      observer:onNext(...)
    end

    local function onError(e)
      observer:onError(e)
    end

    local function onCompleted()
      if not hasValue then
        observer:onNext(util.unpack(defaults))
      end

      observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the values of the original delayed by a time period.
-- @arg {number|function} time - An amount in milliseconds to delay by, or a function which returns
--                                this value.
-- @arg {Scheduler} scheduler - The scheduler to run the Observable on.
-- @returns {Observable}
function Observable:delay(time, scheduler)
  time = type(time) ~= 'function' and util.constant(time) or time

  return Observable.create(function(observer)
    local actions = {}

    local function delay(key)
      return function(...)
        local arg = util.pack(...)
        local handle = scheduler:schedule(function()
          observer[key](observer, util.unpack(arg))
        end, time())
        table.insert(actions, handle)
      end
    end

    local subscription = self:subscribe(delay('onNext'), delay('onError'), delay('onCompleted'))

    return Subscription.create(function()
      if subscription then subscription:unsubscribe() end
      for i = 1, #actions do
        actions[i]:unsubscribe()
      end
    end)
  end)
end

--- Returns a new Observable that produces the values from the original with duplicates removed.
-- @returns {Observable}
function Observable:distinct()
  return Observable.create(function(observer)
    local values = {}

    local function onNext(x)
      if not values[x] then
        observer:onNext(x)
      end

      values[x] = true
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that only produces values from the original if they are different from
-- the previous value.
-- @arg {function} comparator - A function used to compare 2 values. If unspecified, == is used.
-- @returns {Observable}
function Observable:distinctUntilChanged(comparator)
  comparator = comparator or util.eq

  return Observable.create(function(observer)
    local first = true
    local currentValue = nil

    local function onNext(value, ...)
      local values = util.pack(...)
      util.tryWithObserver(observer, function()
        if first or not comparator(value, currentValue) then
          observer:onNext(value, util.unpack(values))
          currentValue = value
          first = false
        end
      end)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that produces the nth element produced by the source Observable.
-- @arg {number} index - The index of the item, with an index of 1 representing the first.
-- @returns {Observable}
function Observable:elementAt(index)
  if not index or type(index) ~= 'number' then
    error('Expected a number')
  end

  return Observable.create(function(observer)
    local subscription
    local i = 1

    local function onNext(...)
      if i == index then
        observer:onNext(...)
        observer:onCompleted()
        if subscription then
          subscription:unsubscribe()
        end
      else
        i = i + 1
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    subscription = self:subscribe(onNext, onError, onCompleted)
    return subscription
  end)
end

--- Returns a new Observable that only produces values of the first that satisfy a predicate.
-- @arg {function} predicate - The predicate used to filter values.
-- @returns {Observable}
function Observable:filter(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if predicate(...) then
          return observer:onNext(...)
        end
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the first value of the original that satisfies a
-- predicate.
-- @arg {function} predicate - The predicate used to find a value.
function Observable:find(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if predicate(...) then
          observer:onNext(...)
          return observer:onCompleted()
        end
      end, ...)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that only produces the first result of the original.
-- @returns {Observable}
function Observable:first()
  return self:take(1)
end

--- Returns a new Observable that transform the items emitted by an Observable into Observables,
-- then flatten the emissions from those into a single Observable
-- @arg {function} callback - The function to transform values from the original Observable.
-- @returns {Observable}
function Observable:flatMap(callback)
  callback = callback or util.identity
  return self:map(callback):flatten()
end

--- Returns a new Observable that uses a callback to create Observables from the values produced by
-- the source, then produces values from the most recent of these Observables.
-- @arg {function=identity} callback - The function used to convert values to Observables.
-- @returns {Observable}
function Observable:flatMapLatest(callback)
  callback = callback or util.identity
  return Observable.create(function(observer)
    local innerSubscription

    local function onNext(...)
      observer:onNext(...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local function subscribeInner(...)
      if innerSubscription then
        innerSubscription:unsubscribe()
      end

      return util.tryWithObserver(observer, function(...)
        innerSubscription = callback(...):subscribe(onNext, onError)
      end, ...)
    end

    local subscription = self:subscribe(subscribeInner, onError, onCompleted)
    return Subscription.create(function()
      if innerSubscription then
        innerSubscription:unsubscribe()
      end

      if subscription then
        subscription:unsubscribe()
      end
    end)
  end)
end

--- Returns a new Observable that subscribes to the Observables produced by the original and
-- produces their values.
-- @returns {Observable}
function Observable:flatten()
  return Observable.create(function(observer)
    local subscriptions = {}

    local function onError(message)
      return observer:onError(message)
    end

    local function onNext(observable)
      local function innerOnNext(...)
        observer:onNext(...)
      end

      local subscription = observable:subscribe(innerOnNext, onError, util.noop)
      subscriptions[#subscriptions + 1] = subscription
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    subscriptions[#subscriptions + 1] = self:subscribe(onNext, onError, onCompleted)
    return Subscription.create(function ()
      for i = 1, #subscriptions do
        subscriptions[i]:unsubscribe()
      end
    end)
  end)
end

--- Returns an Observable that terminates when the source terminates but does not produce any
-- elements.
-- @returns {Observable}
function Observable:ignoreElements()
  return Observable.create(function(observer)
    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(nil, onError, onCompleted)
  end)
end

--- Returns a new Observable that only produces the last result of the original.
-- @returns {Observable}
function Observable:last()
  return Observable.create(function(observer)
    local value
    local empty = true

    local function onNext(...)
      value = {...}
      empty = false
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      if not empty then
        observer:onNext(util.unpack(value or {}))
      end

      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the values of the original transformed by a function.
-- @arg {function} callback - The function to transform values from the original Observable.
-- @returns {Observable}
function Observable:map(callback)
  return Observable.create(function(observer)
    callback = callback or util.identity

    local function onNext(...)
      return util.tryWithObserver(observer, function(...)
        return observer:onNext(callback(...))
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the maximum value produced by the original.
-- @returns {Observable}
function Observable:max()
  return self:reduce(math.max)
end

--- Returns a new Observable that produces the values produced by all the specified Observables in
-- the order they are produced.
-- @arg {Observable...} sources - One or more Observables to merge.
-- @returns {Observable}
function Observable:merge(...)
  local sources = {...}
  table.insert(sources, 1, self)

  return Observable.create(function(observer)
    local completed = {}
    local subscriptions = {}

    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted(i)
      return function()
        table.insert(completed, i)

        if #completed == #sources then
          observer:onCompleted()
        end
      end
    end

    for i = 1, #sources do
      subscriptions[i] = sources[i]:subscribe(onNext, onError, onCompleted(i))
    end

    return Subscription.create(function ()
      for i = 1, #sources do
        if subscriptions[i] then subscriptions[i]:unsubscribe() end
      end
    end)
  end)
end

--- Returns a new Observable that produces the minimum value produced by the original.
-- @returns {Observable}
function Observable:min()
  return self:reduce(math.min)
end

--- Returns an Observable that produces the values of the original inside tables.
-- @returns {Observable}
function Observable:pack()
  return self:map(util.pack)
end

--- Returns two Observables: one that produces values for which the predicate returns truthy for,
-- and another that produces values for which the predicate returns falsy.
-- @arg {function} predicate - The predicate used to partition the values.
-- @returns {Observable}
-- @returns {Observable}
function Observable:partition(predicate)
  return self:filter(predicate), self:reject(predicate)
end

--- Returns a new Observable that produces values computed by extracting the given keys from the
-- tables produced by the original.
-- @arg {string...} keys - The key to extract from the table. Multiple keys can be specified to
--                         recursively pluck values from nested tables.
-- @returns {Observable}
function Observable:pluck(key, ...)
  if not key then return self end

  if type(key) ~= 'string' and type(key) ~= 'number' then
    return Observable.throw('pluck key must be a string')
  end

  return Observable.create(function(observer)
    local function onNext(t)
      return observer:onNext(t[key])
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end):pluck(...)
end

--- Returns a new Observable that produces a single value computed by accumulating the results of
-- running a function on each value produced by the original Observable.
-- @arg {function} accumulator - Accumulates the values of the original Observable. Will be passed
--                               the return value of the last call as the first argument and the
--                               current values as the rest of the arguments.
-- @arg {*} seed - A value to pass to the accumulator the first time it is run.
-- @returns {Observable}
function Observable:reduce(accumulator, seed)
  return Observable.create(function(observer)
    local result = seed
    local first = true

    local function onNext(...)
      if first and seed == nil then
        result = ...
        first = false
      else
        return util.tryWithObserver(observer, function(...)
          result = accumulator(result, ...)
        end, ...)
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      observer:onNext(result)
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces values from the original which do not satisfy a
-- predicate.
-- @arg {function} predicate - The predicate used to reject values.
-- @returns {Observable}
function Observable:reject(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        if not predicate(...) then
          return observer:onNext(...)
        end
      end, ...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that restarts in the event of an error.
-- @arg {number=} count - The maximum number of times to retry.  If left unspecified, an infinite
--                        number of retries will be attempted.
-- @returns {Observable}
function Observable:retry(count)
  return Observable.create(function(observer)
    local subscription
    local retries = 0

    local function onNext(...)
      return observer:onNext(...)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local function onError(message)
      if subscription then
        subscription:unsubscribe()
      end

      retries = retries + 1
      if count and retries > count then
        return observer:onError(message)
      end

      subscription = self:subscribe(onNext, onError, onCompleted)
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces its most recent value every time the specified observable
-- produces a value.
-- @arg {Observable} sampler - The Observable that is used to sample values from this Observable.
-- @returns {Observable}
function Observable:sample(sampler)
  if not sampler then error('Expected an Observable') end

  return Observable.create(function(observer)
    local latest = {}

    local function setLatest(...)
      latest = util.pack(...)
    end

    local function onNext()
      if #latest > 0 then
        return observer:onNext(util.unpack(latest))
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local sourceSubscription = self:subscribe(setLatest, onError)
    local sampleSubscription = sampler:subscribe(onNext, onError, onCompleted)

    return Subscription.create(function()
      if sourceSubscription then sourceSubscription:unsubscribe() end
      if sampleSubscription then sampleSubscription:unsubscribe() end
    end)
  end)
end

--- Returns a new Observable that produces values computed by accumulating the results of running a
-- function on each value produced by the original Observable.
-- @arg {function} accumulator - Accumulates the values of the original Observable. Will be passed
--                               the return value of the last call as the first argument and the
--                               current values as the rest of the arguments.  Each value returned
--                               from this function will be emitted by the Observable.
-- @arg {*} seed - A value to pass to the accumulator the first time it is run.
-- @returns {Observable}
function Observable:scan(accumulator, seed)
  return Observable.create(function(observer)
    local result = seed
    local first = true

    local function onNext(...)
      if first and seed == nil then
        result = ...
        first = false
      else
        return util.tryWithObserver(observer, function(...)
          result = accumulator(result, ...)
          observer:onNext(result)
        end, ...)
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that skips over a specified number of values produced by the original
-- and produces the rest.
-- @arg {number=1} n - The number of values to ignore.
-- @returns {Observable}
function Observable:skip(n)
  n = n or 1

  return Observable.create(function(observer)
    local i = 1

    local function onNext(...)
      if i > n then
        observer:onNext(...)
      else
        i = i + 1
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that omits a specified number of values from the end of the original
-- Observable.
-- @arg {number} count - The number of items to omit from the end.
-- @returns {Observable}
function Observable:skipLast(count)
  if not count or type(count) ~= 'number' then
    error('Expected a number')
  end

  local buffer = {}
  return Observable.create(function(observer)
    local function emit()
      if #buffer > count and buffer[1] then
        local values = table.remove(buffer, 1)
        observer:onNext(util.unpack(values))
      end
    end

    local function onNext(...)
      emit()
      table.insert(buffer, util.pack(...))
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      emit()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that skips over values produced by the original until the specified
-- Observable produces a value.
-- @arg {Observable} other - The Observable that triggers the production of values.
-- @returns {Observable}
function Observable:skipUntil(other)
  return Observable.create(function(observer)
    local triggered = false
    local function trigger()
      triggered = true
    end

    other:subscribe(trigger, trigger, trigger)

    local function onNext(...)
      if triggered then
        observer:onNext(...)
      end
    end

    local function onError()
      if triggered then
        observer:onError()
      end
    end

    local function onCompleted()
      if triggered then
        observer:onCompleted()
      end
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that skips elements until the predicate returns falsy for one of them.
-- @arg {function} predicate - The predicate used to continue skipping values.
-- @returns {Observable}
function Observable:skipWhile(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local skipping = true

    local function onNext(...)
      if skipping then
        util.tryWithObserver(observer, function(...)
          skipping = predicate(...)
        end, ...)
      end

      if not skipping then
        return observer:onNext(...)
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces the specified values followed by all elements produced by
-- the source Observable.
-- @arg {*...} values - The values to produce before the Observable begins producing values
--                      normally.
-- @returns {Observable}
function Observable:startWith(...)
  local values = util.pack(...)
  return Observable.create(function(observer)
    observer:onNext(util.unpack(values))
    return self:subscribe(observer)
  end)
end

--- Returns an Observable that produces a single value representing the sum of the values produced
-- by the original.
-- @returns {Observable}
function Observable:sum()
  return self:reduce(function(x, y) return x + y end, 0)
end

--- Given an Observable that produces Observables, returns an Observable that produces the values
-- produced by the most recently produced Observable.
-- @returns {Observable}
function Observable:switch()
  return Observable.create(function(observer)
    local innerSubscription

    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    local function switch(source)
      if innerSubscription then
        innerSubscription:unsubscribe()
      end

      innerSubscription = source:subscribe(onNext, onError, nil)
    end

    local subscription = self:subscribe(switch, onError, onCompleted)
    return Subscription.create(function()
      if innerSubscription then
        innerSubscription:unsubscribe()
      end

      if subscription then
        subscription:unsubscribe()
      end
    end)
  end)
end

--- Returns a new Observable that only produces the first n results of the original.
-- @arg {number=1} n - The number of elements to produce before completing.
-- @returns {Observable}
function Observable:take(n)
  n = n or 1

  return Observable.create(function(observer)
    if n <= 0 then
      observer:onCompleted()
      return
    end

    local i = 1

    local function onNext(...)
      observer:onNext(...)

      i = i + 1

      if i > n then
        observer:onCompleted()
      end
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that produces a specified number of elements from the end of a source
-- Observable.
-- @arg {number} count - The number of elements to produce.
-- @returns {Observable}
function Observable:takeLast(count)
  if not count or type(count) ~= 'number' then
    error('Expected a number')
  end

  return Observable.create(function(observer)
    local buffer = {}

    local function onNext(...)
      table.insert(buffer, util.pack(...))
      if #buffer > count then
        table.remove(buffer, 1)
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      for i = 1, #buffer do
        observer:onNext(util.unpack(buffer[i]))
      end
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that completes when the specified Observable fires.
-- @arg {Observable} other - The Observable that triggers completion of the original.
-- @returns {Observable}
function Observable:takeUntil(other)
  return Observable.create(function(observer)
    local function onNext(...)
      return observer:onNext(...)
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    other:subscribe(onCompleted, onCompleted, onCompleted)

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns a new Observable that produces elements until the predicate returns falsy.
-- @arg {function} predicate - The predicate used to continue production of values.
-- @returns {Observable}
function Observable:takeWhile(predicate)
  predicate = predicate or util.identity

  return Observable.create(function(observer)
    local taking = true

    local function onNext(...)
      if taking then
        util.tryWithObserver(observer, function(...)
          taking = predicate(...)
        end, ...)

        if taking then
          return observer:onNext(...)
        else
          return observer:onCompleted()
        end
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Runs a function each time this Observable has activity. Similar to subscribe but does not
-- create a subscription.
-- @arg {function=} onNext - Run when the Observable produces values.
-- @arg {function=} onError - Run when the Observable encounters a problem.
-- @arg {function=} onCompleted - Run when the Observable completes.
-- @returns {Observable}
function Observable:tap(_onNext, _onError, _onCompleted)
  _onNext = _onNext or util.noop
  _onError = _onError or util.noop
  _onCompleted = _onCompleted or util.noop

  return Observable.create(function(observer)
    local function onNext(...)
      util.tryWithObserver(observer, function(...)
        _onNext(...)
      end, ...)

      return observer:onNext(...)
    end

    local function onError(message)
      util.tryWithObserver(observer, function()
        _onError(message)
      end)

      return observer:onError(message)
    end

    local function onCompleted()
      util.tryWithObserver(observer, function()
        _onCompleted()
      end)

      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that unpacks the tables produced by the original.
-- @returns {Observable}
function Observable:unpack()
  return self:map(util.unpack)
end

--- Returns an Observable that takes any values produced by the original that consist of multiple
-- return values and produces each value individually.
-- @returns {Observable}
function Observable:unwrap()
  return Observable.create(function(observer)
    local function onNext(...)
      local values = {...}
      for i = 1, #values do
        observer:onNext(values[i])
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that produces a sliding window of the values produced by the original.
-- @arg {number} size - The size of the window. The returned observable will produce this number
--                      of the most recent values as multiple arguments to onNext.
-- @returns {Observable}
function Observable:window(size)
  if not size or type(size) ~= 'number' then
    error('Expected a number')
  end

  return Observable.create(function(observer)
    local window = {}

    local function onNext(value)
      table.insert(window, value)

      if #window >= size then
        observer:onNext(util.unpack(window))
        table.remove(window, 1)
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    return self:subscribe(onNext, onError, onCompleted)
  end)
end

--- Returns an Observable that produces values from the original along with the most recently
-- produced value from all other specified Observables. Note that only the first argument from each
-- source Observable is used.
-- @arg {Observable...} sources - The Observables to include the most recent values from.
-- @returns {Observable}
function Observable:with(...)
  local sources = {...}

  return Observable.create(function(observer)
    local latest = setmetatable({}, {__len = util.constant(#sources)})
    local subscriptions = {}

    local function setLatest(i)
      return function(value)
        latest[i] = value
      end
    end

    local function onNext(value)
      return observer:onNext(value, util.unpack(latest))
    end

    local function onError(e)
      return observer:onError(e)
    end

    local function onCompleted()
      return observer:onCompleted()
    end

    for i = 1, #sources do
      subscriptions[i] = sources[i]:subscribe(setLatest(i), util.noop, util.noop)
    end

    subscriptions[#sources + 1] = self:subscribe(onNext, onError, onCompleted)
    return Subscription.create(function ()
      for i = 1, #sources + 1 do
        if subscriptions[i] then subscriptions[i]:unsubscribe() end
      end
    end)
  end)
end

--- Returns an Observable that merges the values produced by the source Observables by grouping them
-- by their index.  The first onNext event contains the first value of all of the sources, the
-- second onNext event contains the second value of all of the sources, and so on.  onNext is called
-- a number of times equal to the number of values produced by the Observable that produces the
-- fewest number of values.
-- @arg {Observable...} sources - The Observables to zip.
-- @returns {Observable}
function Observable.zip(...)
  local sources = util.pack(...)
  local count = #sources

  return Observable.create(function(observer)
    local values = {}
    local active = {}
    local subscriptions = {}
    for i = 1, count do
      values[i] = {n = 0}
      active[i] = true
    end

    local function onNext(i)
      return function(value)
        table.insert(values[i], value)
        values[i].n = values[i].n + 1

        local ready = true
        for i = 1, count do
          if values[i].n == 0 then
            ready = false
            break
          end
        end

        if ready then
          local payload = {}

          for i = 1, count do
            payload[i] = table.remove(values[i], 1)
            values[i].n = values[i].n - 1
          end

          observer:onNext(util.unpack(payload))
        end
      end
    end

    local function onError(message)
      return observer:onError(message)
    end

    local function onCompleted(i)
      return function()
        active[i] = nil
        if not next(active) or values[i].n == 0 then
          return observer:onCompleted()
        end
      end
    end

    for i = 1, count do
      subscriptions[i] = sources[i]:subscribe(onNext(i), onError, onCompleted(i))
    end

    return Subscription.create(function()
      for i = 1, count do
        if subscriptions[i] then subscriptions[i]:unsubscribe() end
      end
    end)
  end)
end

--- @class ImmediateScheduler
-- @description Schedules Observables by running all operations immediately.
local ImmediateScheduler = {}
ImmediateScheduler.__index = ImmediateScheduler
ImmediateScheduler.__tostring = util.constant('ImmediateScheduler')

--- Creates a new ImmediateScheduler.
-- @returns {ImmediateScheduler}
function ImmediateScheduler.create()
  return setmetatable({}, ImmediateScheduler)
end

--- Schedules a function to be run on the scheduler. It is executed immediately.
-- @arg {function} action - The function to execute.
function ImmediateScheduler:schedule(action)
  action()
end

--- @class CooperativeScheduler
-- @description Manages Observables using coroutines and a virtual clock that must be updated
-- manually.
local CooperativeScheduler = {}
CooperativeScheduler.__index = CooperativeScheduler
CooperativeScheduler.__tostring = util.constant('CooperativeScheduler')

--- Creates a new CooperativeScheduler.
-- @arg {number=0} currentTime - A time to start the scheduler at.
-- @returns {CooperativeScheduler}
function CooperativeScheduler.create(currentTime)
  local self = {
    tasks = {},
    currentTime = currentTime or 0
  }

  return setmetatable(self, CooperativeScheduler)
end

--- Schedules a function to be run after an optional delay.  Returns a subscription that will stop
-- the action from running.
-- @arg {function} action - The function to execute. Will be converted into a coroutine. The
--                          coroutine may yield execution back to the scheduler with an optional
--                          number, which will put it to sleep for a time period.
-- @arg {number=0} delay - Delay execution of the action by a virtual time period.
-- @returns {Subscription}
function CooperativeScheduler:schedule(action, delay)
  local task = {
    thread = coroutine.create(action),
    due = self.currentTime + (delay or 0)
  }

  table.insert(self.tasks, task)

  return Subscription.create(function()
    return self:unschedule(task)
  end)
end

function CooperativeScheduler:unschedule(task)
  for i = 1, #self.tasks do
    if self.tasks[i] == task then
      table.remove(self.tasks, i)
    end
  end
end

--- Triggers an update of the CooperativeScheduler. The clock will be advanced and the scheduler
-- will run any coroutines that are due to be run.
-- @arg {number=0} delta - An amount of time to advance the clock by. It is common to pass in the
--                         time in seconds or milliseconds elapsed since this function was last
--                         called.
function CooperativeScheduler:update(delta)
  self.currentTime = self.currentTime + (delta or 0)

  local i = 1
  while i <= #self.tasks do
    local task = self.tasks[i]

    if self.currentTime >= task.due then
      local success, delay = coroutine.resume(task.thread)

      if coroutine.status(task.thread) == 'dead' then
        table.remove(self.tasks, i)
      else
        task.due = math.max(task.due + (delay or 0), self.currentTime)
        i = i + 1
      end

      if not success then
        error(delay)
      end
    else
      i = i + 1
    end
  end
end

--- Returns whether or not the CooperativeScheduler's queue is empty.
function CooperativeScheduler:isEmpty()
  return not next(self.tasks)
end

--- @class TimeoutScheduler
-- @description A scheduler that uses luvit's timer library to schedule events on an event loop.
local TimeoutScheduler = {}
TimeoutScheduler.__index = TimeoutScheduler
TimeoutScheduler.__tostring = util.constant('TimeoutScheduler')

--- Creates a new TimeoutScheduler.
-- @returns {TimeoutScheduler}
function TimeoutScheduler.create()
  return setmetatable({}, TimeoutScheduler)
end

--- Schedules an action to run at a future point in time.
-- @arg {function} action - The action to run.
-- @arg {number=0} delay - The delay, in milliseconds.
-- @returns {Subscription}
function TimeoutScheduler:schedule(action, delay, ...)
  local timer = require 'timer'
  local subscription
  local handle = timer.setTimeout(delay, action, ...)
  return Subscription.create(function()
    timer.clearTimeout(handle)
  end)
end

--- @class Subject
-- @description Subjects function both as an Observer and as an Observable. Subjects inherit all
-- Observable functions, including subscribe. Values can also be pushed to the Subject, which will
-- be broadcasted to any subscribed Observers.
local Subject = setmetatable({}, Observable)
Subject.__index = Subject
Subject.__tostring = util.constant('Subject')

--- Creates a new Subject.
-- @returns {Subject}
function Subject.create()
  local self = {
    observers = {},
    stopped = false
  }

  return setmetatable(self, Subject)
end

--- Creates a new Observer and attaches it to the Subject.
-- @arg {function|table} onNext|observer - A function called when the Subject produces a value or
--                                         an existing Observer to attach to the Subject.
-- @arg {function} onError - Called when the Subject terminates due to an error.
-- @arg {function} onCompleted - Called when the Subject completes normally.
function Subject:subscribe(onNext, onError, onCompleted)
  local observer

  if util.isa(onNext, Observer) then
    observer = onNext
  else
    observer = Observer.create(onNext, onError, onCompleted)
  end

  table.insert(self.observers, observer)

  return Subscription.create(function()
    for i = 1, #self.observers do
      if self.observers[i] == observer then
        table.remove(self.observers, i)
        return
      end
    end
  end)
end

--- Pushes zero or more values to the Subject. They will be broadcasted to all Observers.
-- @arg {*...} values
function Subject:onNext(...)
  if not self.stopped then
    for i = #self.observers, 1, -1 do
      self.observers[i]:onNext(...)
    end
  end
end

--- Signal to all Observers that an error has occurred.
-- @arg {string=} message - A string describing what went wrong.
function Subject:onError(message)
  if not self.stopped then
    for i = #self.observers, 1, -1 do
      self.observers[i]:onError(message)
    end

    self.stopped = true
  end
end

--- Signal to all Observers that the Subject will not produce any more values.
function Subject:onCompleted()
  if not self.stopped then
    for i = #self.observers, 1, -1 do
      self.observers[i]:onCompleted()
    end

    self.stopped = true
  end
end

Subject.__call = Subject.onNext

--- @class AsyncSubject
-- @description AsyncSubjects are subjects that produce either no values or a single value.  If
-- multiple values are produced via onNext, only the last one is used.  If onError is called, then
-- no value is produced and onError is called on any subscribed Observers.  If an Observer
-- subscribes and the AsyncSubject has already terminated, the Observer will immediately receive the
-- value or the error.
local AsyncSubject = setmetatable({}, Observable)
AsyncSubject.__index = AsyncSubject
AsyncSubject.__tostring = util.constant('AsyncSubject')

--- Creates a new AsyncSubject.
-- @returns {AsyncSubject}
function AsyncSubject.create()
  local self = {
    observers = {},
    stopped = false,
    value = nil,
    errorMessage = nil
  }

  return setmetatable(self, AsyncSubject)
end

--- Creates a new Observer and attaches it to the AsyncSubject.
-- @arg {function|table} onNext|observer - A function called when the AsyncSubject produces a value
--                                         or an existing Observer to attach to the AsyncSubject.
-- @arg {function} onError - Called when the AsyncSubject terminates due to an error.
-- @arg {function} onCompleted - Called when the AsyncSubject completes normally.
function AsyncSubject:subscribe(onNext, onError, onCompleted)
  local observer

  if util.isa(onNext, Observer) then
    observer = onNext
  else
    observer = Observer.create(onNext, onError, onCompleted)
  end

  if self.value then
    observer:onNext(util.unpack(self.value))
    observer:onCompleted()
    return
  elseif self.errorMessage then
    observer:onError(self.errorMessage)
    return
  end

  table.insert(self.observers, observer)

  return Subscription.create(function()
    for i = 1, #self.observers do
      if self.observers[i] == observer then
        table.remove(self.observers, i)
        return
      end
    end
  end)
end

--- Pushes zero or more values to the AsyncSubject.
-- @arg {*...} values
function AsyncSubject:onNext(...)
  if not self.stopped then
    self.value = util.pack(...)
  end
end

--- Signal to all Observers that an error has occurred.
-- @arg {string=} message - A string describing what went wrong.
function AsyncSubject:onError(message)
  if not self.stopped then
    self.errorMessage = message

    for i = 1, #self.observers do
      self.observers[i]:onError(self.errorMessage)
    end

    self.stopped = true
  end
end

--- Signal to all Observers that the AsyncSubject will not produce any more values.
function AsyncSubject:onCompleted()
  if not self.stopped then
    for i = 1, #self.observers do
      if self.value then
        self.observers[i]:onNext(util.unpack(self.value))
      end

      self.observers[i]:onCompleted()
    end

    self.stopped = true
  end
end

AsyncSubject.__call = AsyncSubject.onNext

--- @class BehaviorSubject
-- @description A Subject that tracks its current value. Provides an accessor to retrieve the most
-- recent pushed value, and all subscribers immediately receive the latest value.
local BehaviorSubject = setmetatable({}, Subject)
BehaviorSubject.__index = BehaviorSubject
BehaviorSubject.__tostring = util.constant('BehaviorSubject')

--- Creates a new BehaviorSubject.
-- @arg {*...} value - The initial values.
-- @returns {BehaviorSubject}
function BehaviorSubject.create(...)
  local self = {
    observers = {},
    stopped = false
  }

  if select('#', ...) > 0 then
    self.value = util.pack(...)
  end

  return setmetatable(self, BehaviorSubject)
end

--- Creates a new Observer and attaches it to the BehaviorSubject. Immediately broadcasts the most
-- recent value to the Observer.
-- @arg {function} onNext - Called when the BehaviorSubject produces a value.
-- @arg {function} onError - Called when the BehaviorSubject terminates due to an error.
-- @arg {function} onCompleted - Called when the BehaviorSubject completes normally.
function BehaviorSubject:subscribe(onNext, onError, onCompleted)
  local observer

  if util.isa(onNext, Observer) then
    observer = onNext
  else
    observer = Observer.create(onNext, onError, onCompleted)
  end

  local subscription = Subject.subscribe(self, observer)

  if self.value then
    observer:onNext(util.unpack(self.value))
  end

  return subscription
end

--- Pushes zero or more values to the BehaviorSubject. They will be broadcasted to all Observers.
-- @arg {*...} values
function BehaviorSubject:onNext(...)
  self.value = util.pack(...)
  return Subject.onNext(self, ...)
end

--- Returns the last value emitted by the BehaviorSubject, or the initial value passed to the
-- constructor if nothing has been emitted yet.
-- @returns {*...}
function BehaviorSubject:getValue()
  if self.value ~= nil then
    return util.unpack(self.value)
  end
end

BehaviorSubject.__call = BehaviorSubject.onNext

--- @class ReplaySubject
-- @description A Subject that provides new Subscribers with some or all of the most recently
-- produced values upon subscription.
local ReplaySubject = setmetatable({}, Subject)
ReplaySubject.__index = ReplaySubject
ReplaySubject.__tostring = util.constant('ReplaySubject')

--- Creates a new ReplaySubject.
-- @arg {number=} bufferSize - The number of values to send to new subscribers. If nil, an infinite
--                             buffer is used (note that this could lead to memory issues).
-- @returns {ReplaySubject}
function ReplaySubject.create(n)
  local self = {
    observers = {},
    stopped = false,
    buffer = {},
    bufferSize = n
  }

  return setmetatable(self, ReplaySubject)
end

--- Creates a new Observer and attaches it to the ReplaySubject. Immediately broadcasts the most
-- contents of the buffer to the Observer.
-- @arg {function} onNext - Called when the ReplaySubject produces a value.
-- @arg {function} onError - Called when the ReplaySubject terminates due to an error.
-- @arg {function} onCompleted - Called when the ReplaySubject completes normally.
function ReplaySubject:subscribe(onNext, onError, onCompleted)
  local observer

  if util.isa(onNext, Observer) then
    observer = onNext
  else
    observer = Observer.create(onNext, onError, onCompleted)
  end

  local subscription = Subject.subscribe(self, observer)

  for i = 1, #self.buffer do
    observer:onNext(util.unpack(self.buffer[i]))
  end

  return subscription
end

--- Pushes zero or more values to the ReplaySubject. They will be broadcasted to all Observers.
-- @arg {*...} values
function ReplaySubject:onNext(...)
  table.insert(self.buffer, util.pack(...))
  if self.bufferSize and #self.buffer > self.bufferSize then
    table.remove(self.buffer, 1)
  end

  return Subject.onNext(self, ...)
end

ReplaySubject.__call = ReplaySubject.onNext

Observable.wrap = Observable.buffer
Observable['repeat'] = Observable.replicate

return {
  util = util,
  Subscription = Subscription,
  Observer = Observer,
  Observable = Observable,
  ImmediateScheduler = ImmediateScheduler,
  CooperativeScheduler = CooperativeScheduler,
  TimeoutScheduler = TimeoutScheduler,
  Subject = Subject,
  AsyncSubject = AsyncSubject,
  BehaviorSubject = BehaviorSubject,
  ReplaySubject = ReplaySubject
}