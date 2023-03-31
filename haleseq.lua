-- 8scsp.
-- @eigen
--
--      8 stage       complex
--
--     sequencing    programmer
--
--    ▼ instructions below ▼
--
-- original idea by @hale


-- ------------------------------------------------------------------------
-- deps

local lattice = require "lattice"

local nb = include("haleseq/lib/nb/lib/nb")

local Stage = include("haleseq/lib/stage")
include("haleseq/lib/core")


-- ------------------------------------------------------------------------
-- conf

local FPS = 15
local GRID_FPS = 15

local STEPS_GRID_X_OFFSET = 4

local NB_STEPS = 8
local NB_VSTEPS = 4

local MCLOCK_DIVS = 64



-- ------------------------------------------------------------------------
-- state

local s_lattice

local g = nil
local has_grid = false

local g_knob = nil

function grid_connect_maybe(_g)
  if not has_grid then
    g = grid.connect()
    if g.device ~= nil then
      g.key = grid_key
      has_grid = true
    end
  end
end

function grid_remove_maybe(_g)
  if g.device.port == _g.port then
    -- current grid got deconnected
    has_grid = false
  end
end


-- ------------------------------------------------------------------------
-- state - sequence values

local prev_step = nil
local step = 1
local vstep = 1

local stages = {}
local seqvals = {}

local V_MAX = 1000
local V_NB_OCTAVES = 10
local V_TRIG = 500

function init_stages(nb)
  for x=1,nb do
    stages[x] = Stage:new()
  end
end

function init_seqvals(nbx, nby)
  for x=1,nbx do
    seqvals[x] = {}
    for y=1,nby do
      seqvals[x][y] = V_MAX/2
    end
  end
end

function randomize_seqvals_octaves()
  local nbx = tab.count(seqvals)
  local nby = tab.count(seqvals[1])

  srand(math.random(10000))

  local octave = 3
  local octave_v = V_MAX / V_NB_OCTAVES
  for y=1,nby do
    for x=1,nbx do
      local note = math.random(octave_v + 1) - 1
      seqvals[x][y] = octave * octave_v + note
    end
    octave = octave + 1
  end
end

function randomize_seqvals()
  local nbx = tab.count(seqvals)
  local nby = tab.count(seqvals[1])

  srand(math.random(10000))

  for y=1,nby do
    for x=1,nbx do
      local note = math.random(round(3*V_MAX/4) + 1) - 1
      seqvals[x][y] = note
    end
  end
end

function are_all_stage_skip()
  local nb_skipped = 0
  for s=1,NB_STEPS do
    if stages[s]:get_mode() == Stage.M_SKIP then
      nb_skipped = nb_skipped + 1
    end
  end
  return (nb_skipped == NB_STEPS)
end

-- ------------------------------------------------------------------------
-- playback

local nb_playing_notes = {}

function note_play(vs)
  local player = params:lookup_param("nb_voice_"..vs):get_player()

  if nb_playing_notes[vs] ~= nil then
    player:note_off(nb_playing_notes[vs])
    nb_playing_notes[vs] = nil
  end

  local v = 0
  local s = step
  if stages[s]:get_mode() == Stage.M_TIE and prev_step ~= nil then
    s = prev_step
  end

  if vs > NB_VSTEPS then -- special multiplexed step
    v = seqvals[s][vstep]
  else
    v = seqvals[s][vs]
  end

  local note = round(util.linlin(0, V_MAX, 0, 127, v))
  local vel = 0.8

  -- print("playing "..note)

  player:note_on(note, vel)
  nb_playing_notes[vs] = note
end

function all_notes_off()
  for vs=1,NB_VSTEPS+1 do
    if nb_playing_notes[vs] ~= nil then
      player:note_off(nb_playing_notes[vs])
      nb_playing_notes[vs] = nil
    end
  end
end

-- ------------------------------------------------------------------------
-- script lifecycle

local redraw_clock
local grid_redraw_clock

function get_first_nb_voice_midi_param_option_id(voice_id)
  local nb_voices = params:lookup_param("nb_voice_"..voice_id).options
  for i, v in ipairs(nb_voices) do
    if util.string_starts(v, "midi: ") and not (util.string_starts(v, "midi: nb ") or util.string_starts(v, "midi: virtual ")) then
      return i
    end
  end
end

function init()
  screen.aa(0)
  screen.line_width(1)

  s_lattice = lattice:new{}

  grid_connect_maybe()

  init_stages(NB_STEPS)
  init_seqvals(NB_STEPS, NB_VSTEPS)
  randomize_seqvals()

  nb.voice_count = NB_VSTEPS + 1
  nb:init()
  for vs=1, NB_VSTEPS + 1 do
    nb_playing_notes[vs] = nil
    nb:add_param("nb_voice_"..vs, "nb Voice "..vs)
  end
  nb:add_player_params()

  -- FIXME: can't be set at init like that...
  -- NB: bind multiplexed voice to first midi out if found
  -- local vs_mux = NB_VSTEPS + 1
  -- local p_id = get_first_nb_voice_midi_param_option_id(vs_mux)
  -- if p_id ~= nil then
  --   params:set("nb_voice_"..vs_mux, p_id)
  -- end


  local CLOCK_DIVS = {'off', '1/1', '1/2', '1/4', '1/8', '1/16', '1/32', '1/64'}
  params:add_option("clock_div", "Clock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, '1/16'))
  params:add_option("vclock_div", "VClock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, '1/16'))

  redraw_clock = clock.run(
    function()
      local step_s = 1 / FPS
      while true do
        clock.sleep(step_s)
        redraw()
      end
  end)
  grid_redraw_clock = clock.run(
    function()
      local step_s = 1 / GRID_FPS
      while true do
        clock.sleep(step_s)
        grid_redraw()
      end
  end)

  local sprocket = s_lattice:new_sprocket{
    action = mclock_tick,
    division = 1/MCLOCK_DIVS,
    enabled = true
  }
  s_lattice:start()
end

function cleanup()
  all_notes_off()
  clock.cancel(redraw_clock)
  clock.cancel(grid_redraw_clock)
  s_lattice:destroy()
end


-- ------------------------------------------------------------------------
-- sequence

local next_step = nil
local clock_acum = 0
local preset = 1
local reverse = false
local hold = false

local next_vstep = nil
local vclock_acum = 0

-- base1 modulo
function mod1(v, m)
  return ((v - 1) % m) + 1
end

function is_whole_number(v)
  return (v%1 == 0)
end

function clock_div_opt_v(o)
  local m = {
    ['off'] = 0,
    ['1/1'] = 1,
    ['1/2'] = 2,
    ['1/4'] = 4,
    ['1/8'] = 8,
    ['1/16'] = 16,
    ['1/32'] = 32,
    ['1/64'] = 64,
  }
  return m[o]
end

function clock_tick()
  local clock_div = clock_div_opt_v(params:string("clock_div"))
  clock_acum = clock_acum + clock_div / MCLOCK_DIVS

  -- NB: if clock is off (clock_div at 0), take immediate effect
  --     otherwise, wait for quantization
  if next_step ~= nil and ((clock_div == 0) or (clock_acum >= 1)) then
    if (clock_acum >= 1) then
      clock_acum = 0
    end
    step = next_step
    next_step = nil
    return true
  end

  if clock_acum < 1 then
    return false
  end
  clock_acum = 0

  if hold then
    return false
  end

  if are_all_stage_skip() then
    return false
  end

  if stages[step]:get_mode() ~= Stage.M_TIE then
    prev_step = step
  end

  local sign = reverse and -1 or 1
  step = mod1(step + sign, NB_STEPS)
  while stages[step]:get_mode() == Stage.M_SKIP do
    local sign = reverse and -1 or 1
    step = mod1(step + sign, NB_STEPS)
  end

  return true
end

function vclock_tick()
  vclock_acum = vclock_acum + clock_div_opt_v(params:string("vclock_div")) / MCLOCK_DIVS
  if vclock_acum < 1 then
    return false
  end
  vclock_acum = 0

  if next_vstep ~= nil then
    vstep = next_vstep
    next_vstep = nil
    return true
  end
  vstep = mod1(vstep + 1, NB_VSTEPS)
  -- print(step)

  return true
end

function mclock_tick()
  local ticked = clock_tick()
  local vticked = vclock_tick()

  if ticked then
    for vs=1,NB_VSTEPS do
      note_play(vs)
    end
  end
  if ticked or vticked then
    note_play(NB_VSTEPS+1)
  end
end

function reset()
  next_step = 1
end

function reset_preset()
  next_step = preset
end

function vreset()
  next_vstep = 1
end


-- ------------------------------------------------------------------------
-- grid

local G_Y_PRESS = 8
local G_Y_KNOB = 2

function grid_redraw()
  g:all(0)

  local l = 3

  for s=1,NB_STEPS do
    l = 3
    local x = s + STEPS_GRID_X_OFFSET
    local y = 1

    g:led(x, y, 1)     -- trig out
    y = y + 1
    g:led(x, y, 1)     -- trig in
    for vs=1,NB_VSTEPS do
      if (step == s) and (vstep == vs) then
        l = 15
      else
        l = round(util.linlin(0, V_MAX, 0, 12, seqvals[s][vs]))
      end
      g:led(x, G_Y_KNOB+vs-1, l) -- value
    end
    y = y + NB_VSTEPS + 1
    --                -- <pad>
    l = (preset == s) and 5 or 1
    g:led(x, y, l)   -- tie / run / skip
    l = 1
    if next_step ~= nil then
      if next_step == s then
        l = 5
      elseif step == s then
        l = 2
      end
    elseif step == s then
      l = 10
    end
    g:led(x, G_Y_PRESS, l)   -- press / select in
  end

  local x = STEPS_GRID_X_OFFSET + NB_STEPS + 1
  for vs=1,NB_VSTEPS do
    l = (vstep == vs) and 5 or 1
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

  g:refresh()
end

function grid_key(x, y, z)
  if x > STEPS_GRID_X_OFFSET and x <= STEPS_GRID_X_OFFSET + NB_STEPS then
    if y == G_Y_PRESS and z >= 1 then
      preset = x - STEPS_GRID_X_OFFSET
      reset_preset()
      return
    end
    if y == 7 and z >= 1 then
      local s = x - STEPS_GRID_X_OFFSET
      stages[s]:mode_cycle()
      return
    end
    if y >= G_Y_KNOB and y < G_Y_KNOB + NB_STEPS then
      if z >= 1 then
        local s = x - STEPS_GRID_X_OFFSET
        local vs = y - G_Y_KNOB + 1
        g_knob = {s, vs}
      else
        g_knob = nil
      end
    end
  end

  if x == 16 and y == 1 and z >= 1 then
    vreset()
    return
  end
  if x == 16 and y == 3 and z >= 1 then
    reset()
    return
  end
  if x == 16 and y == 4 then
    hold = (z >= 1)
    return
  end
  if x == 16 and y == 5 and z >= 1 then
    reset_preset()
    return
  end
  if x == 16 and y == 6 then
    reverse = (z >= 1)
    return
  end
end

-- ------------------------------------------------------------------------
-- controls

function enc(n, d)

  if g_knob ~= nil then
    local v = g_knob[1]
    local vs = g_knob[2]
    seqvals[v][vs] = util.clamp(seqvals[v][vs] + d*5, 0, V_MAX)
    return
  end

  if n == 1 then
    params:set("clock_tempo", params:get("clock_tempo") + d)
    return
  end
  if n == 2 then
    local sign = math.floor(d/math.abs(d))
    params:set("clock_div", params:get("clock_div") + sign)
    return
  end
  if n == 3 then
    local sign = math.floor(d/math.abs(d))
    params:set("vclock_div", params:get("vclock_div") + sign)
    return
  end
end

-- ------------------------------------------------------------------------
-- screen

local SCREEN_W = 128
local SCREEN_H = 64

local SCREEN_STAGE_W = 9
-- local SCREEN_STAGE_Y_OFFSET = 12
local SCREEN_STAGE_Y_OFFSET = 1

function draw_nana(x, y, fill)
  screen.aa(1)
  screen.level(10)
  local radius = math.floor((SCREEN_STAGE_W/2) - 1)
  screen.move(x + radius + 1, y)
  screen.circle(x + radius + 1, y + radius + 1, radius)
  if fill then
    screen.fill()
  else
    screen.stroke()
  end
end

function draw_trig_out(x, y, trig)
  -- panel grahpic (square)
  screen.aa(0)
  screen.level(5)
  screen.rect(x, y, SCREEN_STAGE_W, SCREEN_STAGE_W)
  screen.stroke()
  -- nana
  if trig then
    draw_nana(x, y, trig)
  end
end

function draw_trig_in(x, y, trig)
  -- panel grahpic (triangle)
  screen.aa(0)
  screen.level(5)
  screen.move(x, y)
  screen.line(round(x+SCREEN_STAGE_W/2), round(y+SCREEN_STAGE_W*2/3))
  screen.line(x+SCREEN_STAGE_W, y)
  screen.line(x, y)
  screen.stroke()
  -- nana
  -- draw_nana(x, y, trig)
end

function draw_mode_run(x, y)
  screen.aa(1)
  screen.level(5)
  screen.pixel(round(x + SCREEN_STAGE_W / 2), round(y + SCREEN_STAGE_W / 2))
end

function draw_mode_tie(x, y)
  screen.aa(1)
  screen.level(5)
  screen.move(x, round(y + SCREEN_STAGE_W/2))
  screen.line(x + SCREEN_STAGE_W, round(y + SCREEN_STAGE_W/2))
end

function draw_mode_skip(x, y)
  screen.aa(0)
  screen.level(5)
  screen.move(x, y)
  screen.line(x + SCREEN_STAGE_W, y + SCREEN_STAGE_W)
  screen.stroke()
  screen.move(x + SCREEN_STAGE_W, y)
  screen.line(x, y + SCREEN_STAGE_W)
  screen.stroke()
end

function draw_knob(x, y, v)
  -- draw_nana(x, y, false)
  local radius = SCREEN_STAGE_W/2

  x = x + SCREEN_STAGE_W/2
  y = y + SCREEN_STAGE_W/2
  v = v - (V_MAX / 4)

  screen.move(round(x), round(y))
  screen.line(x + radius * cos(v/V_MAX) * -1, y + radius * sin(v/V_MAX))
  screen.stroke()
end

function redraw_stage(x, y, s)
  -- trig out
  draw_trig_out(x, y, (step == s))

  -- trig in
  y = y + SCREEN_STAGE_W
  draw_trig_in(x, y, false)

  -- vals
  for vs=1,NB_VSTEPS do
    y = y + SCREEN_STAGE_W
    draw_knob(x, y, seqvals[s][vs])
  end

  -- mode
  y = y + SCREEN_STAGE_W
  local mode = stages[s]:get_mode()
  if mode == Stage.M_RUN then
    draw_mode_run(x, y)
  elseif mode == Stage.M_TIE then
    draw_mode_tie(x, y)
  elseif mode == Stage.M_SKIP then
    draw_mode_skip(x, y)
  end
end

function redraw()
  screen.clear()

  screen.level(15)

  -- clock(s)
  screen.move(0, 8)
  screen.text(params:get("clock_tempo") .. " BPM ")
  screen.move(0, 18)
  screen.text(params:string("clock_div"))
  screen.move(0, 28)
  screen.text(params:string("vclock_div"))

  -- seq
  local x = (SCREEN_W - (NB_STEPS * SCREEN_STAGE_W)) / 2
  for s=1,NB_STEPS do
    redraw_stage(x, SCREEN_STAGE_Y_OFFSET, s)
    x = x + SCREEN_STAGE_W
  end

  -- vseq
  local y = SCREEN_STAGE_Y_OFFSET + 2 * SCREEN_STAGE_W
  for vs=1,NB_VSTEPS do
    draw_trig_out(x, y, (vstep == vs))
    y = y + SCREEN_STAGE_W
  end

  screen.update()
end
