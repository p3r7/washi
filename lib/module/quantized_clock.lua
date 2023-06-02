-- haleseq. module/quantized clock

local Comparator = include("haleseq/lib/submodule/comparator")
local Out = include("haleseq/lib/submodule/out")

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")
include("haleseq/lib/core")


-- ------------------------------------------------------------------------

local QuantizedClock = {}
QuantizedClock.__index = QuantizedClock


-- ------------------------------------------------------------------------
-- constructors

function QuantizedClock.new(id, STATE,
                            mclock_div, divs, base)
  local p = setmetatable({}, QuantizedClock)

  p.kind = "quantized_clock"

  p.id = id -- id for param lookup
  p.fqid = p.kind.."_"..id -- fully qualified id for i/o routing lookup

  -- --------------------------------

  p.STATE = STATE

  -- --------------------------------
  -- I/O

  p.ins = {}
  p.outs = {}

  if base == nil then base = 0 end

  p.i = Comparator.new(p.fqid, p)

  p.acum = 0

  p.mclock_div = mclock_div

  p.divs = divs
  p.div_states = {}
  p.div_outs = {}
  for i, div in ipairs(divs) do
    p.div_outs[i] = Out.new(p.fqid.."_"..div, p)
    p.div_states[i] = false
  end
  return p
end


function QuantizedClock:process_ins()
  self:tick()
end

-- ------------------------------------------------------------------------
-- init

function QuantizedClock.init(id, STATE, mclock_div, divs)
  local q = QuantizedClock.new(id, STATE, mclock_div, divs, base)

  if STATE ~= nil then
    STATE.ins[q.i.id] = q.i
    for _, o in ipairs(q.div_outs) do
      STATE.outs[o.id] = o
    end
  end

  return q
end


-- ------------------------------------------------------------------------
-- getters

-- function QuantizedClock:is_ticking(div)
--   local i = tab.key(self.divs, div)
--   return self.div_states[i]
-- end


-- ------------------------------------------------------------------------
-- clock

function QuantizedClock:mod(v, m)
  if self.base == 1 then
    return mod1(v, m)
  else -- base == 0
    return v % m
  end
end

function QuantizedClock:tick()
  self.acum = self.acum + 1
  for i, d in ipairs(self.divs) do
    local m = self.mclock_div / d
    local state = (self:mod(self.acum, m) == 0)
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

function QuantizedClock.redraw(x, y, acum)
    for i, v in ipairs(CLOCK_DIVS) do
    if v ~= 'off' then
      local trig = acum % (MCLOCK_DIVS / CLOCK_DIV_DENOMS[i-1]) == 0
      paperface.trig_out(x, y, trig)
      screen.move(x + SCREEN_STAGE_W + 2, y + SCREEN_STAGE_W - 2)
      screen.text(v)
      y = y + SCREEN_STAGE_W
    end
  end
end


-- ------------------------------------------------------------------------
return QuantizedClock
