-- haleseq. in


-- ------------------------------------------------------------------------

local In = {}
In.__index = In


-- ------------------------------------------------------------------------
-- constructors

function In.new(id, parent, callback)
  local p = setmetatable({}, In)
  p.kind = "in"
  p.id = id
  p.parent = parent
  if callback then
    p.callback = callback
  end
  p.v = 0
  return p
end


-- ------------------------------------------------------------------------
-- api

function In:reset()
  self.v = 0
end

function In:update(v)
  self.v = v
  if self.callback then
    self.callback()
  end
end

-- ------------------------------------------------------------------------

return In
