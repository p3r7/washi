-- haleseq. module/norns clock

local In = include("haleseq/lib/submodule/in")
local Out = include("haleseq/lib/submodule/out")

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local NornsClock = {}
NornsClock.__index = NornsClock


-- ------------------------------------------------------------------------
-- constructors

function NornsClock.new(STATE)
  local p = setmetatable({}, NornsClock)

  p.kind = "norns_clock"
  p.id = "norns_clock"
  p.fqid = "norns_clock"

  p.STATE = STATE

  p.ins = {}
  p.outs = {}
  p.i = In.new(p.fqid, p)
  p.o = Out.new(p.fqid, p)

  return p
end

function NornsClock.init(STATE)
  local c = NornsClock.new(STATE)

  if STATE ~= nil then
    STATE.ins[c.i.id] = c.i
    STATE.outs[c.o.id] = c.o
  end

  return c
end

function NornsClock:process_ins()
  if self.i.triggered then
    self.o.v = V_MAX/2
  end
end

-- ------------------------------------------------------------------------
-- screen

function NornsClock.redraw(x, y, acum)
    -- local trig = (math.abs(os.clock() - last_mclock_tick_t) < PULSE_T)
  local trig = acum % (MCLOCK_DIVS / 4) == 0
  paperface.trig_out(x, y, trig)
  screen.move(x + SCREEN_STAGE_W + 2, y + SCREEN_STAGE_W - 2)
  screen.text(params:get("clock_tempo") .. " BPM ")
end

-- ------------------------------------------------------------------------

return NornsClock
