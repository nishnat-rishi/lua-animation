local Animation = {} -- *5
Animation.__index = Animation

function Animation.createController()
  return setmetatable({
      ids = {},
      duration = {},
      current = {},
      frames = {},
      curve = {},
      tweener = {},
      running = {},
      continuous = {},
      reversible = {},
      reverse = {},
      _trash = {},
      _pendingRegistrations = {},
      }, Animation)
end

function Animation.register(self, params) -- *1
  for id, _ in pairs(self.ids) do
    if id == params.id then
      self._pendingRegistrations[id] = params
      return
    end
  end
  self.ids[params.id] = true
  self:_rawRegister(params)
end

function Animation.deregister(self, id)
  self._trash[id] = true
end

function Animation.update(self)
  for id, _ in pairs(self.ids) do
    if self.running[id] then
      if not self.reversible[id] then
        self.current[id] = self.current[id] + 1
        if self.current[id] >= #self.frames[id] then -- *4
          if not self.continuous[id] then 
            self:pause(id) 
          end
          self:reset(id)
        end
      else
        if not self.reverse[id] then
          self.current[id] = self.current[id] + 1
          if self.current[id] >= #self.frames[id] then
            if not self.continuous[id] then 
              self:pause(id) 
            end
            self:flip(id)
          end
        else
          self.current[id] = self.current[id] - 1
          if self.current[id] <= 1 then
            if not self.continuous[id] then 
              self:pause(id) 
            end
            self:flip(id)
          end
        end
      end
      self.tweener[id].object[self.tweener[id].index] = self.frames[id][self.current[id]]
    end
  end
  if next(self._trash) then -- *7
    self:_clear()
  end
  if next(self._pendingRegistrations) then
    self:_registerPending()
  end
end

function Animation.toggle(self, id)
  if self.ids[id] ~= nil then
    self.running[id] = not self.running[id]
  end
end

function Animation.play(self, id)
  if self.ids[id] ~= nil then
    self.running[id] = true
  end
end

function Animation.pause(self, id)
  if self.ids[id] ~= nil then
    self.running[id] = false
  end
end

function Animation.reset(self, id)
  if self.ids[id] ~= nil then
    self.current[id] = 1
  end
end

function Animation.flip(self, id)
  if self.ids[id] ~= nil then
    self.reverse[id] = not self.reverse[id]
  end
end

function Animation._clear(self)
  for id, _ in pairs(self._trash) do
    if (self.current[id] - math.floor(#self.frames[id] / 2)) <= 0 then -- *6
      self.tweener[id].object[self.tweener[id].index] = self.tweener[id].initial
    else
      self.tweener[id].object[self.tweener[id].index] = self.tweener[id].final
    end
    self.duration[id] = nil
    self.current[id] = nil
    self.running[id] = nil
    self.curve[id] = nil
    self.reversible[id] = nil
    self.reverse[id] = nil
    self.continuous[id] = nil
    self.tweener[id] = nil
    self.frames[id] = nil
    self.ids[id] = nil
    self._trash[id] = nil
  end
end

function Animation._registerPending(self)
  for id, params in pairs(self._pendingRegistrations) do
    self:_rawRegister(params)
    self._pendingRegistrations[id] = nil
  end
end

function Animation._rawRegister(self, params)
  self.duration[params.id] = params.duration
  self.current[params.id] = 1
  self.running[params.id] = false
  self.curve[params.id] = params.curve
  self.reversible[params.id] = params.reversible or false
  self.reverse[params.id] = false
  self.continuous[params.id] = params.continuous or false
  self.tweener[params.id] = params.tweener
  self:_constructFrames(params.id)
end

function Animation._constructFrames(self, id)
  local init, fin = self.tweener[id].initial, self.tweener[id].final
  local cFn, cI, cF = self.curve[id].animFunction, self.curve[id].initial, self.curve[id].final
  local numFrames = math.ceil(self.duration[id] * 60)
  local cInc = (cF - cI) / numFrames
  local range = fin - init
  
  self.frames[id] = {0}
  local frames = self.frames[id]
  local cSum = 0
  
  j = cI
  
  for i = 2, numFrames+1 do
    cSum = cSum + cFn(j)
    frames[i] = cFn(j)
    j = j + cInc
  end
  for i = 2, numFrames+1 do
    frames[i] = frames[i-1] + frames[i] / cSum
  end
  for i = 1, numFrames+1 do
    frames[i] = init + frames[i] * range
  end
end

return Animation

--------------------
----- COMMENTS -----
--------------------

--[[ 

*1: params = {id, duration, curve, tweener} *2 *3

*2: curve = {animFn, initial, final}

*3: tweener = {object, index, initial, final}

*4: For now, after animation ends, pause and reset the animation.

*5: This module requires a bit more deliberation! Registration is an
    expensive operation! Make sure to perform all registrations upfront as much
    as possible!

*6: On deregistration, the variable takes on the frame-wise closest value.

*7: This feels like it should be part of a hierarchy. Same functions have been
    implemented multiple times to do the same disposal, rawRegistration and so
    on routines.
    
--]]