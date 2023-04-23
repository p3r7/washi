-- haleseq. module/haleseq

local musicutil = require "musicutil"

local Stage = include("haleseq/lib/stage")

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")
include("haleseq/lib/core")


-- ------------------------------------------------------------------------

local Haleseq = {}
Haleseq.__index = Haleseq


-- ------------------------------------------------------------------------
-- constructors

function Haleseq.new(id, nb_steps, nb_vsteps,
                    hclock, vclock)
  local p = setmetatable({}, Haleseq)

  p.id = id

  p.nb_steps = nb_steps
  p.nb_vsteps = nb_vsteps

  p.stages = {}
  for s=1,nb_steps do
    p.stages[s] = Stage:new()
  end

  p.seqvals = {}
  for s=1,nb_steps do
    p.seqvals[s] = {}
    for vs=1,nb_vsteps do
      p.seqvals[s][vs] = V_MAX/2
    end
  end

  p.step = 1
  p.vstep = 1

  p.prev_step = nil
  p.next_step = nil
  p.next_vstep = nil
  p.is_resetting = false

  p.last_step_t = 0
  p.last_vstep_t = 0
  p.last_preset_t = 0

  p.reverse = false
  p.vreverse = false
  p.hold = false

  p.g_knob = nil
  p.g_btn = nil

  p.hclock = hclock
  p.vclock = vclock

  return p
end


-- ------------------------------------------------------------------------
-- getters

function Haleseq:get_id()
  return self.id
end

function Haleseq:get_hclock()
  return self.hclock
end

function Haleseq:get_vclock()
  return self.vclock
end

function Haleseq:get_nb_vsteps()
  return self.nb_vsteps
end

function Haleseq:is_editing_knob()
  if self.g_knob ~= nil then
    return true
  end
  return false
end


-- ------------------------------------------------------------------------
-- state - pos

function Haleseq:has_next_step()
  if self.next_step ~= nil then
    return true
  end
  return false
end

function Haleseq:has_next_vstep()
  if self.next_vstep ~= nil then
    return true
  end
  return false
end

function Haleseq:reset()
  self.is_resetting = true
  self.next_step = 1
end

function Haleseq:vreset()
  self.next_vstep = 1
end

function Haleseq:reset_preset()
  self.next_step = params:get("preset_"..self.id)
end

function Haleseq:are_all_stage_skip(ignore_preset)
  local nb_skipped = 0

  local start = params:get("preset_"..self.id)
  if ignore_preset then
    start = 1
  end

  for s=start,self.nb_steps do
    if self.stages[s]:get_mode() == Stage.M_SKIP then
      nb_skipped = nb_skipped + 1
    end
  end
  return (nb_skipped == (self.nb_steps-start+1))
end

function Haleseq:clock_tick()

  local clock_is_off = (params:string("clock_div_"..self.id) == "off")
  local clock_div_id = params:get("clock_div_"..self.id) - 1 -- 1rst elem is "off"

  local clock_is_ticking = (not clock_is_off) and self.hclock:is_ticking(CLOCK_DIV_DENOMS[clock_div_id])


  if clock_is_off and not self.next_step then
    return false
  end

  -- --------------------------------
  -- case 1: forced to go to `next_step`

  if self.next_step ~= nil then
    if not (clock_is_off or clock_is_ticking) then
      return false
    end

    self.step = self.next_step
    self.next_step = nil
    self.last_step_t = os.clock()

    -- NB: i/o patching, to rewrite
    -- if self.stages[self.step].o ~= nil and not (clock_div == 0) then
    --   self.next_step = self.stages[step].o
    -- end

    return true
  end

  if clock_is_off or not clock_is_ticking then
    return false
  end

  -- --------------------------------
  -- case 2: hold

  if self.hold then
    return false
  end

  -- --------------------------------
  -- case 3: advance

  -- prevent deadlock
  if self:are_all_stage_skip(self.is_resetting) then
    return false
  end

  if self.stages[self.step]:get_mode() ~= Stage.M_TIE then
    self.prev_step = self.step
  end

  local sign = self.reverse and -1 or 1

  -- advance once ...
  self.step = mod1(self.step + sign, self.nb_steps)

  -- ... skip until at preset ...
  if not self.is_resetting then
    while self.step < params:get("preset_"..self.id) do
      self.step = mod1(self.step + sign, self.nb_steps)
    end
  end

  -- ... skip stages in skip mode ...
  while self.stages[self.step]:get_mode() == Stage.M_SKIP do
    self.step = mod1(self.step + sign, self.nb_steps)
  end
  if self.step >= params:get("preset_"..self.id) then
    self.is_resetting = false
  end

  -- ... skip (again) until at preset ...
  if not self.is_resetting then
    while self.step < params:get("preset_"..self.id) do
      self.step = mod1(self.step + sign, self.nb_steps)
    end
  end

  -- NB: i/o patching, to rewrite
  -- if self.stages[self.step].o ~= nil then
  --   self.next_step = self.stages[step].o
  -- end

  self.last_step_t = os.clock()
  return true
end

function Haleseq:vclock_tick()

  local vclock_is_off = (params:string("vclock_div_"..self.id) == "off")
  local vclock_div_id = params:get("vclock_div_"..self.id) - 1 -- 1rst elem is "off"

  local vclock_is_ticking = (not vclock_is_off) and self.vclock:is_ticking(CLOCK_DIV_DENOMS[vclock_div_id])


  -- --------------------------------
  -- case 1: forced to go to `next_vstep`

  if self.next_vstep ~= nil then
    if not (vclock_is_off or vclock_is_ticking) then
      return false
    end

    self.vstep = self.next_vstep
    self.next_vstep = nil
    self.last_vstep_t = os.clock()

    return true
  end

  if vclock_is_off or not vclock_is_ticking then
    return false
  end

  -- --------------------------------
  -- case 2: hold

  -- NB: hold has no effect on vclock

  -- --------------------------------
  -- case 3: advance

  local sign = self.vreverse and -1 or 1

  self.vstep = mod1(self.vstep + sign, self.nb_vsteps)
  self.last_vstep_t = os.clock()

  return true
end


-- ------------------------------------------------------------------------
-- playback

function Haleseq:get_current_play_stage()
  local s = self.step
  if self.stages[s]:get_mode() == Stage.M_TIE and self.prev_step ~= nil then
    s = self.prev_step
  end
  return s
end

-- A / B / C / D
function Haleseq:get_current_play_volts(vs)
  local s = self:get_current_play_stage()

  return self.seqvals[s][vs]
end

--- ABCD
function Haleseq:get_current_mux_play_volts()
  local s = self:get_current_play_stage()
  return self.seqvals[s][self.vstep]
end


-- ------------------------------------------------------------------------
-- state - sequences

function Haleseq:randomize_seqvals_octaves()
  local nbx = self.nb_steps
  local nby = self.nb_vsteps

  srand(math.random(10000))

  local octave = 3
  local octave_v = V_MAX / V_NB_OCTAVES
  for y=1,nby do
    for x=1,nbx do
      local note = math.random(octave_v + 1) - 1
      self.seqvals[x][y] = octave * octave_v + note
    end
    octave = octave + 1
  end
end

function Haleseq:randomize_seqvals_blip_bloop()
  local nbx = self.nb_steps
  local nby = self.nb_vsteps

  srand(math.random(10000))

  for y=1,nby do
    for x=1,nbx do
      local note = math.random(round(3*V_MAX/4) + 1) - 1
      self.seqvals[x][y] = note
    end
  end
end

function Haleseq:randomize_seqvals_scale(root_note)
  local nbx = self.nb_steps
  local nby = self.nb_vsteps

  local octaves = {1, 2, 3, 4, 5, 7, 8, 9}

  srand(math.random(10000))

  local chord_root_freq = tab.key(musicutil.NOTE_NAMES, root_note) - 1
  local scale = musicutil.generate_scale_of_length(chord_root_freq, nbx)
  local nb_notes_in_scale = tab.count(scale)

  for y=1,nby do
    for x=1,nbx do
      local note = scale[math.random(nb_notes_in_scale)] + 12 * octaves[math.random(#octaves)]
      self.seqvals[x][y] = round(util.linlin(0, 127, 0, V_MAX, note))
    end
  end
end


-- ------------------------------------------------------------------------
-- init

function Haleseq:init_params()
  local id = self.id

  params:add_group("haleseq_"..id, "haleseq #"..id, 1)

  params:add_trigger("rnd_seqs_"..id, "Randomize Seqs")
  params:set_action("rnd_seqs_"..id,
                    function(_v)
                      if params:string("rnd_seq_mode") == 'Scale' then
                        self:randomize_seqvals_scale(params:string("rnd_seq_root"))
                      else
                        self:randomize_seqvals_blip_bloop()
                      end
                    end
  )

  params:add{type = "number", id = "preset_"..id, name = "Preset", min = 1, max = NB_STEPS, default = 1}
  params:set_action("preset_"..id,
                    function(_v)
                      self.last_preset_t = os.clock()
                      self:reset_preset()
                    end
  )

  params:add_trigger("fw_"..id, "Forward")
  params:set_action("fw_"..id,
                    function(_v)
                      clock_acum = clock_acum + 1
                      mclock_tick(nil, true)
                    end
  )
  params:add_trigger("bw_"..id, "Backward")
  params:set_action("bw_"..id,
                    function(_v)
                      local reverse_prev = self.reverse
                      self.reverse = true
                      clock_acum = clock_acum + 1
                      mclock_tick(nil, true)
                      self.reverse = reverse_prev
                    end
  )
  params:add_trigger("vfw_"..id, "VForward")
  params:set_action("vfw_"..id,
                    function(_v)
                      vclock_acum = vclock_acum + 1
                      mclock_tick(nil, true)
                    end
  )
  params:add_trigger("vbw_"..id, "VBackward")
  params:set_action("vbw_"..id,
                    function(_v)
                      local vreverse_prev = self.vreverse
                      self.vreverse = true
                      vclock_acum = vclock_acum + 1
                      mclock_tick(nil, true)
                      self.vreverse = vreverse_prev
                    end
  )

  params:add_option("clock_div_"..id, "Clock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, '1/16'))
  params:add_option("vclock_div_"..id, "VClock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, '1/2'))
end

function Haleseq.init(id, nb_steps, nb_vsteps, hclock, vclock)
  local h = Haleseq.new(id, nb_steps, nb_vsteps, hclock, vclock)
  h:init_params()
  return h
end


-- ------------------------------------------------------------------------
-- knobs

function Haleseq:knob(n, d)
  local v = self.g_knob[1]
  local vs = self.g_knob[2]
  self.seqvals[v][vs] = util.clamp(self.seqvals[v][vs] + d*5, 0, V_MAX)
end

function Haleseq:knob_vs()
  if self.g_knob == nil then
    return
  end
  return self.g_knob[2]
end

function Haleseq:knob_volts()
  if self.g_knob == nil then
    return
  end
  local v = self.g_knob[1]
  local vs = self.g_knob[2]
  return self.seqvals[v][vs]
end

-- ------------------------------------------------------------------------
-- grid

local G_Y_PRESS = 8
local G_Y_KNOB = 2

local STEPS_GRID_X_OFFSET = 4


function Haleseq:grid_redraw(g)
  local l = 3

  for s=1,self.nb_steps do
    l = 3
    local x = s + STEPS_GRID_X_OFFSET
    local y = 1

    g:led(x, y, 1)     -- trig out
    y = y + 1
    g:led(x, y, 1)     -- trig in
    for vs=1,self.nb_vsteps do
      if (self.step == s) and (self.vstep == vs) then
        l = 15
      else
        l = round(util.linlin(0, V_MAX, 0, 12, self.seqvals[s][vs]))
      end
      g:led(x, G_Y_KNOB+vs, l) -- value
    end
    y = y + self.nb_vsteps + 1
    --                -- <pad>
    l = 1
    local mode = self.stages[s]:get_mode()
    if (params:get("preset_"..self.id) == s) then
      l = 8
    elseif mode == Stage.M_RUN then
      l = 2
    elseif mode == Stage.M_SKIP then
      l = 0
    elseif mode == Stage.M_TIE then
      l = 4
    end
    g:led(x, y, l)   -- tie / run / skip
    l = 1
    if self.next_step ~= nil then
      if self.next_step == s then
        l = 5
      elseif self.step == s then
        l = 2
      end
    elseif self.step == s then
      l = 10
    end
    g:led(x, G_Y_PRESS, l)   -- press / select in
  end

  local x = STEPS_GRID_X_OFFSET + self.nb_steps + 1
  for vs=1,self.nb_vsteps do
    l = (self.vstep == vs) and 5 or 1
    g:led(x, 2+vs, l) -- v out
  end

  g:led(16, 1, 5) -- vreset
  g:led(16, 2, 1) -- vclock
  g:led(16, 3, 5) -- reset
  g:led(16, 4, 3) -- hold
  g:led(16, 5, 5) -- preset
  g:led(16, 6, 3) -- reverse
  g:led(16, 7, 3) -- clock
  -- preset manual
end

function Haleseq:grid_key(x, y, z)
  if x > STEPS_GRID_X_OFFSET and x <= STEPS_GRID_X_OFFSET + self.nb_steps then
    if y == G_Y_PRESS then
      if (z >= 1) then
        local s = x - STEPS_GRID_X_OFFSET
        self.g_btn = s
        params:set("preset_"..self.id, s)
        self.last_preset_t = os.clock()
        -- mclock_tick(nil, true)
      else
        self.g_btn = nil
      end
      return
    end
    if y == 7 and z >= 1 then
      local s = x - STEPS_GRID_X_OFFSET
      self.stages[s]:mode_cycle()
      return
    end
    if y >= G_Y_KNOB and y < G_Y_KNOB + NB_STEPS then
      if z >= 1 then
        local s = x - STEPS_GRID_X_OFFSET
        local vs = y - G_Y_KNOB
        self.g_knob = {s, vs}
      else
        self.g_knob = nil
      end
    end
  end

  if x == 16 and y == 1 and z >= 1 then
    self:vreset()
    return
  end
  if x == 16 and y == 3 and z >= 1 then
    self:reset()
    return
  end
  if x == 16 and y == 4 then
    self.hold = (z >= 1)
    return
  end
  if x == 16 and y == 5 and z >= 1 then
    self:reset_preset()
    return
  end
  if x == 16 and y == 6 then
    self.reverse = (z >= 1)
    return
  end
end


-- ------------------------------------------------------------------------
-- screen

local SCREEN_STAGE_OUT_Y = 1
local SCREEN_STAGE_KNOB_Y = 2
local SCREEN_STAGE_MODE_Y = 6
local SCREEN_PRESET_IN_Y = 7

function Haleseq:redraw_stage(x, y, s)
  local y2

  -- trig out
  y2 = y + (SCREEN_STAGE_OUT_Y - 1) * SCREEN_STAGE_W
  local at = (self.step == s)
  local trig = at and (math.abs(os.clock() - self.last_step_t) < PULSE_T)
   paperface.trig_out(x, y2, trig)
  if not trig and at then
    paperface.banana(x, y2, false)
  end

  -- trig in
  y2 = y + (SCREEN_PRESET_IN_Y - 1) * SCREEN_STAGE_W
  if params:get("preset_"..self.id) == s then
    if (self.g_btn == s) then
      paperface.trig_in(x, y2, true)
    else
      paperface.trig_in(x, y2, false, true)
    end
  else
    paperface.trig_in(x, y2, (self.g_btn == s))
  end

  -- vals
  y2 = y + (SCREEN_STAGE_KNOB_Y - 1) * SCREEN_STAGE_W
  for vs=1,self.nb_vsteps do
    -- l = SCREEN_LEVEL_LABEL
    -- if params:get("preset_"..self.id) == s then
    --   l = SCREEN_LEVEL_LABEL_SPE
    -- end
    -- paperface.rect_label(x, y2, l)
    paperface.rect_label(x, y2)
    l = 1
    if at then
      if (self.vstep == vs) then
        l = SCREEN_LEVEL_LABEL_SPE
      else
        l = 2
      end
    end
    paperface.knob(x, y2, self.seqvals[s][vs], l)
    y2 = y2 + SCREEN_STAGE_W
  end

  -- mode
  y2 = y + (SCREEN_STAGE_MODE_Y - 1) * SCREEN_STAGE_W
  paperface.rect_label(x, y2)
  paperface.mode_switch(x, y2, self.stages[s]:get_mode())
end

function Haleseq:redraw()
  -- seq
  local x = (SCREEN_W - (self.nb_steps * SCREEN_STAGE_W)) / 2
  for s=1,self.nb_steps do
    self:redraw_stage(x, SCREEN_STAGE_Y_OFFSET, s)
    x = x + SCREEN_STAGE_W
  end

  -- vseq
  local y = SCREEN_STAGE_Y_OFFSET + (SCREEN_STAGE_KNOB_Y - 1) * SCREEN_STAGE_W
  for vs=1,self.nb_vsteps do
    local at = (self.vstep == vs)
    local trig = at and (math.abs(os.clock() - self.last_vstep_t) < PULSE_T)
    paperface.trig_out(x, y, trig)
    if not trig and at then
      paperface.banana(x, y, false)
    end
    y = y + SCREEN_STAGE_W
  end

  -- preset gate out
  local y = SCREEN_STAGE_Y_OFFSET
  paperface.trig_out(x, y, math.abs(os.clock() - self.last_preset_t) < PULSE_T, SCREEN_LEVEL_LABEL_SPE)

  x = x + SCREEN_STAGE_W * 2

  paperface.main_in(x, y, trig)
end


-- ------------------------------------------------------------------------

return Haleseq
