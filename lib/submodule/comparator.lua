-- haleseq. comparator

include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local Comparator = {}
Comparator.__index = Comparator


-- ------------------------------------------------------------------------
-- constructors

function Comparator.new(id, parent, callback)
  local p = setmetatable({}, Comparator)
  p.kind = "comparator"
  p.id = id
  p.parent = parent
  if callback then
    p.callback = callback
  end
  p.status = 0
  p.triggered = false
  return p
end


-- ------------------------------------------------------------------------
-- getter/setter

function Comparator:reset()
  -- Comparators act like flip flop, they have memory
end

function Comparator:set(v)
  self.v = v
  if self.callback then
    self.callback()
  end
end

-- TODO: change that
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
