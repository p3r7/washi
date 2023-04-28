-- haleseq. module/norns clock

local Out = include("haleseq/lib/submodule/out")

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local NornsClock = {}
NornsClock.__index = NornsClock


-- ------------------------------------------------------------------------
-- constructors

function NornsClock.new()
  local p = setmetatable({}, NornsClock)

  p.o = Out.new("norns_clock")

  return p
end

function NornsClock.init(outs_map)
  local c = NornsClock.new()

  if outs_map ~= nil then
    outs_map[c.o.id] = c.o
  end

  return c
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
