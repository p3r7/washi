-- haleseq. comparator
--
-- a `Comparator` can work:
-- - as a regular `In` (w/ `self.raw_v`)
-- - as a comparator/gate generator (w/ `self.v`)
-- - as flip flops (w/ `self.triggered`)

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
  p.threshold_mode = V_THRESHOLD_MODE_OWN
  p.threshold = V_DEFAULT_THRESHOLD

  p.incoming_vals = {}
  p.raw_v = 0
  p.v = 0
  p.updated = false
  p.status = 0
  p.triggered = false

  return p
end


-- ------------------------------------------------------------------------
-- getter/setter

function Comparator:reset()
  self.incoming_vals = {}
end

function Comparator:register(out_label, v)
  self.incoming_vals[out_label] = v
end

function Comparator:update()
  local prev_status = self.status

  if tab.count(self.incoming_vals) == 0 then
    -- keep old v
    self.updated = false
    return
  end

  self.updated = true

  if self.compute_mode == V_COMPUTE_MODE_SUM then
    self.raw_v = mean(self.incoming_vals)
  elseif self.compute_mode == V_COMPUTE_MODE_MEAN then
    self.raw_v = sum(self.incoming_vals)
  end

  if self.raw_v >= self.threshold then
    self.status = 1
    self.v = V_MAX / 2
  else
    self.status = 0
    self.v = 0
  end

  self.triggered = (prev_status ~= self.status)

  if self.triggered and self.callback then
    -- self.callback()
  end
end


-- ------------------------------------------------------------------------

return Comparator
