-- haleseq. module/quantized clock

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")
include("haleseq/lib/core")


-- ------------------------------------------------------------------------

local QuantizedClock = {}
QuantizedClock.__index = QuantizedClock


-- ------------------------------------------------------------------------
-- constructors

function QuantizedClock.new(id, mclock_div, divs, base)
  local p = setmetatable({}, QuantizedClock)

  if base == nil then base = 0 end

  p.acum = 0

  p.mclock_div = mclock_div

  p.divs = divs
  p.div_states = {}
  for i, _ in ipairs(divs) do
    p.div_states[i] = false
  end
  return p
end


-- ------------------------------------------------------------------------
-- getters

function QuantizedClock:is_ticking(div)
  local i = tab.key(self.divs, div)
  return self.div_states[i]
end


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
    self.div_states[i] = (self:mod(self.acum, m) == 0)
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
