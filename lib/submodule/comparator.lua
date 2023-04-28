-- haleseq. comparator

include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local Comparator = {}
Comparator.__index = Comparator


-- ------------------------------------------------------------------------
-- constructors

function Comparator.new(id)
  local p = setmetatable({}, Comparator)
  p.id = id
  p.status = 0
  p.triggered = false
  return p
end


-- ------------------------------------------------------------------------
-- getter/setter

function Comparator:reset()
  -- Comparators act like flip flop, they have memory
end

function Comparator:update(v, threshold)
  local prev_status = self.status
  self.triggered = false

  if v >= threshold then
    self.status = 1
    -- just got rising state
    if prev_status ~= self.status then
      self.triggered = true
    end
    self.triggered = true
  else
    self.status = 0
  end
  return self.status
end

function Comparator:get()
  return self.status
end

function Comparator:get_as_volts()
  if self.status then
    return V_MAX / 2
  else
    return 0
  end
end


-- ------------------------------------------------------------------------

return Comparator
