-- haleseq. comparator


-- ------------------------------------------------------------------------

local Comparator = {}
Comparator.__index = Comparator


-- ------------------------------------------------------------------------
-- constructors

function Comparator.new()
  local p = setmetatable({}, Comparator)
  p.status = 0
  return p
end


-- ------------------------------------------------------------------------
-- getter/setter

function Comparator:update(v, threshold)
  if v >= threshold then
    self.status = 1
  else
    self.status = 0
  end
  return self.status
end

function Comparator:get()
  return self.status
end


-- ------------------------------------------------------------------------

return Comparator
