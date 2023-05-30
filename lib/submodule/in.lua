-- haleseq. in

include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local In = {}
In.__index = In


-- ------------------------------------------------------------------------
-- constructors

function In.new(id, parent, callback)
  local p = setmetatable({}, In)

  p.kind = "in"
  p.id = id

  if parent ~= nil then
    p.parent = parent
    if parent.ins ~= nil then
      table.insert(parent.ins, p.id)
    end
  end

  -- REVIEW: not using those anymore
  if callback then
    p.callback = callback
  end

  p.compute_mode = V_COMPUTE_MODE_SUM

  p.incoming_vals = {}
  p.v = 0
  p.updated = false

  return p
end


-- ------------------------------------------------------------------------
-- api

function In:reset()
  self.incoming_vals = {}
end

function In:register(out_label, v)
  self.incoming_vals[out_label] = v
end

function In:update()
  if tab.count(self.incoming_vals) == 0 then
    -- keep old v
    self.updated = false
    return
  end

  local old_v = self.v

  if self.compute_mode == V_COMPUTE_MODE_SUM then
    self.v = mean(self.incoming_vals)
  elseif self.compute_mode == V_COMPUTE_MODE_MEAN then
    self.v = sum(self.incoming_vals)
  end

  self.updated = (old_v ~= self.v)

  if self.callback then
    -- self.callback()
  end
end

-- ------------------------------------------------------------------------

return In
