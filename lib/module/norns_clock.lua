-- washi. module/norns clock

local NornsClock = {}
NornsClock.__index = NornsClock


-- ------------------------------------------------------------------------
-- deps

local Comparator = include("washi/lib/submodule/comparator")
local Out = include("washi/lib/submodule/out")

local paperface = include("washi/lib/paperface")
include("washi/lib/consts")


-- ------------------------------------------------------------------------
-- constructors

function NornsClock.new(STATE,
                       page_id, x, y)
  local p = setmetatable({}, NornsClock)

  p.kind = "norns_clock"
  p.id = "norns_clock"
  p.fqid = "norns_clock"

  -- --------------------------------

  p.STATE = STATE
  STATE.modules[p.fqid] = p

  -- --------------------------------
  -- i/o

  p.ins = {}
  p.outs = {}
  p.i = Comparator.new(p.fqid, p)
  p.o = Out.new(p.fqid, p)

  -- --------------------------------
  -- screen

  p.page = page_id
  p.x = x
  p.y = y

  return p
end

function NornsClock.init(STATE,
                        page_id, x, y)
  local c = NornsClock.new(STATE,
                           page_id, x, y)
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
-- grid

function NornsClock:grid_redraw(g, mult_trig)
  -- dummy output
  local l = 3
  if mult_trig then
    l = 10
  end

  local x = paperface.panel_to_grid_x(g, self.x)
  local y = paperface.panel_to_grid_y(g, self.y)

  g:led(x, y, l)
end


-- ------------------------------------------------------------------------
-- screen

function NornsClock:redraw(mult_trig)
  -- local trig = ((self.parent.STATE.superclk_t - last_mclock_tick_t) < trig_threshold_time())

  local x, y = paperface.panel_grid_to_screen_absolute(self)

  -- local trig = acum % (MCLOCK_DIVS / 8) == 0

  local tame = (self.STATE.grid_mode == M_LINK or self.STATE.grid_mode == M_EDIT)

  paperface.trig_out(x, y, mult_trig, tame)

  screen.level(SCREEN_LEVEL_LABEL)
  screen.move(x, y + 2 * SCREEN_STAGE_W - 2)
  screen.text(params:get("clock_tempo"))
  screen.move(x, y + 3 * SCREEN_STAGE_W - 2)
  screen.text("BPM")


  -- screen.move(x + SCREEN_STAGE_W + 2, y + SCREEN_STAGE_W - 2)
end

-- ------------------------------------------------------------------------

return NornsClock
