-- haleseq. module/pulse divider
--
-- CGS pulse divider

local Comparator = include("haleseq/lib/submodule/comparator")
local Out = include("haleseq/lib/submodule/out")

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local PulseDivider = {}
PulseDivider.__index = PulseDivider


-- ------------------------------------------------------------------------
-- static conf

local CGS_PULSE_DIVS = {2, 3, 4, 5, 6, 7, 8}


-- ------------------------------------------------------------------------
-- constructors

function PulseDivider.new(id, STATE, divs)
  local p = setmetatable({}, PulseDivider)

  p.kind = "pulse_divider"
  p.id = id
  p.fqid = "pulse_divider" .. "_" .. id

  p.STATE = STATE

  p.ins = {}
  p.outs = {}

  p.acum = 0

  if base == nil then base = 0 end
  p.base = base

  p.i = Comparator.new(p.fqid, p)

  if divs == nil then divs = CGS_PULSE_DIVS end
  p.divs = divs
  p.div_states = {}
  p.div_outs = {}
  for i, div in ipairs(p.divs) do
    p.div_outs[i] = Out.new(p.fqid.."_"..div, p)
    p.div_states[i] = false
  end

  return p
end

function PulseDivider.init(id, STATE)
  local q = PulseDivider.new(id, STATE)

  if STATE ~= nil then
    STATE.ins[q.i.id] = q.i
    for _, o in ipairs(q.div_outs) do
      STATE.outs[o.id] = o
    end
  end

  return q
end

function PulseDivider:process_ins()
  if self.i.triggered and self.i.status == 1 then
    self:tick()
  end
end


-- ------------------------------------------------------------------------
-- clock

function PulseDivider:mod(v, m)
  if self.base == 1 then
    return mod1(v, m)
  else -- base == 0
    return v % m
  end
end

function PulseDivider:tick()
  self.acum = self.acum + 1
  for i, d in ipairs(self.divs) do
    local state = (self:mod(self.acum, d) == 0)
    self.div_states[i] = state
    if state then
      self.div_outs[i].v = V_MAX / 2
    else
      self.div_outs[i].v = 0
    end
  end
end


-- ------------------------------------------------------------------------
-- screen

function PulseDivider:redraw(x, y, acum)
  for i, v in ipairs(self.divs) do
    paperface.trig_out(x, y, self.div_states[i])
    screen.move(x + SCREEN_STAGE_W + 2, y + SCREEN_STAGE_W - 2)
    screen.text("/"..v)
    y = y + SCREEN_STAGE_W
  end
end


-- ------------------------------------------------------------------------

return PulseDivider
