-- haleseq. module/norns clock

local NornsClock = {}
NornsClock.__index = NornsClock


-- ------------------------------------------------------------------------
-- deps

local Comparator = include("haleseq/lib/submodule/comparator")
local Out = include("haleseq/lib/submodule/out")

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")


-- ------------------------------------------------------------------------
-- constructors

function NornsClock.new(STATE,
                       screen_id, x, y)
  local p = setmetatable({}, NornsClock)

  p.kind = "norns_clock"
  p.id = "norns_clock"
  p.fqid = "norns_clock"

  -- --------------------------------

  p.STATE = STATE

  -- --------------------------------
  -- i/o

  p.ins = {}
  p.outs = {}
  p.i = Comparator.new(p.fqid, p)
  p.o = Out.new(p.fqid, p)

  -- --------------------------------
  -- screen

  p.screen = screen_id
  p.x = x
  p.y = y

  return p
end

function NornsClock.init(STATE,
                        screen_id, x, y)
  local c = NornsClock.new(STATE,
                           screen_id, x, y)

  if STATE ~= nil then
    STATE.ins[c.i.id] = c.i
    STATE.outs[c.o.id] = c.o
  end

  return c
end


-- ------------------------------------------------------------------------
-- internal logic

function NornsClock:process_ins()
  if self.i.triggered then
    if self.i.status == 1 then
      self.o:update(V_MAX/2)
    else
      self.o:update(0)
    end
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
