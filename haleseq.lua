-- haleseq.
-- @eigen
--
--      8 stage       complex
--
--     sequencing    programmer
--
--    ▼ instructions below ▼
--
-- based on the work of:
-- - Serge Tcherepnin
-- - Ken Stone
-- - Dakota Merlin (@hale)


-- ------------------------------------------------------------------------
-- deps

local lattice = require "lattice"
local musicutil = require "musicutil"
local UI = require "ui"

local nb = include("haleseq/lib/nb/lib/nb")
local inspect = include("haleseq/lib/inspect")

local paperface = include("haleseq/lib/paperface")
patching = include("haleseq/lib/patching")

-- modules
local Haleseq = include("haleseq/lib/module/haleseq")
local Output = include("haleseq/lib/module/output")
local NornsClock = include("haleseq/lib/module/norns_clock")
local QuantizedClock = include("haleseq/lib/module/quantized_clock")
local pulse_divider = include("haleseq/lib/module/pulse_divider")

include("haleseq/lib/core")
include("haleseq/lib/consts")


-- ------------------------------------------------------------------------
-- conf

local FPS = 15
local GRID_FPS = 15

local NB_BARS = 2

-- local NB_HALESEQS = 1
local NB_HALESEQS = 2

local norns_clock
local quantized_clocks
local haleseqs = {}
local outputs = {}

local page_list = {'clock'}
for h=1, NB_HALESEQS do
  table.insert(page_list, 'haleseq '..h)
end
local pages = UI.Pages.new(1, #page_list)
pages:set_index(tab.key(page_list, 'haleseq 1'))


-- ------------------------------------------------------------------------
-- patching

ins = {}
outs = {}
links = {}

local function add_link(o, i)
  patching.add_link(links, o, i)
end

local function remove_link(o, i)
  patching.remove_link(links, o, i)
end


-- ------------------------------------------------------------------------
-- DEBUG

DEBUG = true

local function dbg(v, level)
  if not DEBUG then
    return
  end

  if level == nil then level = 0 end
  local indent = string.rep(" ", level*2)

  local msg = inspect(v)

  -- local lines = {}
  for l in msg:gmatch("[^\r\n]+") do
    -- table.insert(lines, l)
    print(indent .. l)
  end

end

local function dbgtab(t, level)
  if not DEBUG then
    return
  end

  for k,v in pairs(t) do
    dbg(k .. '\t' .. tostring(v), level)
  end
end


local function exec_plan_from_input(in_label, modules, module_out_links, level)
  if modules == nil then modules = {} end
  if module_out_links == nil then module_out_links = {} end
  if level == nil then level = 1 end
  if modules[level] == nil then modules[level] = {} end

  dbg(in_label, level-1)

  local curr_in = ins[in_label]
  if curr_in == nil then
    dbg("!!! in '"..in_label.."' not found", level)
    return modules, module_out_links
  end

  local curr_module = curr_in.parent

  -- anti-feedback mechanism (prevent infinite loops)
  -- for l, level_mods in ipairs(modules) do
  --   if tab.contains(level_mods, curr_module) then
  --     dbg("!!! in '"..in_label.."' already triggered at level "..l..". cutting feedback loop.")
  --     return modules, module_out_links
  --   end
  -- end

  set_insert(modules[level], curr_module)
  if module_out_links[curr_module] == nil then module_out_links[curr_module] = {} end

  local curr_out_labels = curr_module.outs
  if curr_out_labels == nil or tab.count(curr_out_labels) == 0 then -- is at termination module
    -- dbg("!!! at termination branch !!!")
    return modules, module_out_links
  end
  for _, curr_out_label in ipairs(curr_out_labels) do
    local curr_out = outs[curr_out_label]
    if curr_out == nil then
      dbg("!!! out '"..curr_out_label.."' not found", level)
      goto NEXT_OUT
    end

    local next_in_labels = links[curr_out_label]
    if next_in_labels ~= nil then
      for _, next_in_label in ipairs(next_in_labels) do
        dbg(curr_out_label .. " -> " .. next_in_label, level-1)
        if ins[next_in_label] ~= nil then
          set_insert_coord(module_out_links[curr_module], {curr_out, ins[next_in_label]})
        end
        exec_plan_from_input(next_in_label, modules, module_out_links, level+1)
      end
    end

    ::NEXT_OUT::
  end
  return modules, module_out_links
end

-- TODO: add anti-feedback (infinite loop) mechanism
local function exec_plan(out_label, modules, module_out_links, level)

  -- dbg(out_label, level)

  if modules == nil then modules = {} end
  if module_out_links == nil then module_out_links = {} end
  if level == nil then level = 1 end
  if modules[level] == nil then modules[level] = {} end

  local out = outs[out_label]
  if out == nil then
    dbg("!!! "..out_label.." not found", level)
    return modules, module_out_links
  end

  local curr_module = out.parent
  set_insert(modules[level], curr_module)
  if module_out_links[curr_module] == nil then module_out_links[curr_module] = {} end

  local target_ins = links[out_label]
  if target_ins == nil then
    return modules, module_out_links
  end

  for _, in_label in ipairs(target_ins) do
    dbg(out_label .. " -> " .. in_label, level-1)
    local target_input = ins[in_label]
    if target_input ~= nil then
      set_insert_coord(module_out_links[curr_module], {out, target_input})

      local next_out_labels = target_input.parent.outs
      if next_out_labels == nil or tab.count(next_out_labels) == 0 then -- is at termination module
        -- REVIEW: looks kinda ugly to redo same thing as begning of fn
        -- could rewrite the whole fn to take `in_label` instead of an `out_label`
        -- works for now...
        if modules[level+1] == nil then modules[level+1] = {} end
        set_insert(modules[level+1], target_input.parent)
        if module_out_links[target_input.parent] == nil then module_out_links[target_input.parent] = {} end
        -- return modules, module_out_links
        goto NEXT_LINK
      end
      for _, next_out_label in ipairs(next_out_labels) do
        exec_plan(next_out_label, modules, module_out_links, level+1)
      end
    else
      dbg("!!! "..in_label.." not found", level)
    end

    ::NEXT_LINK::
  end

  return modules, module_out_links
end

-- TODO: the trick is to not fire any value in the propagate phase but only retrive the execution plan (map of triggered_module => outbound_links)
-- returned as 2 vals as maps are not ordered in lua
-- also as we're using a set/map, this works as an anti-feedback mechanism (preventing a module to appear twice in sequence)
-- then in this 2nd function, loop over ordered (by level) sequence of triggered_modules, process input vals (`module:process_ins`) & set next module's vals (`target_input:update`)

-- also each module's input value must be stored as a list (when calling `target_input:update`) that gets eval'd & cleared when calling `module:process_ins`

local function reset_all_ins(m)
  if m.ins == nil then
    return
  end
  for _, in_label in ipairs(m.ins) do
    local i = ins[in_label]
    if i ~= nil then
      i:reset()
    end
  end
end

local function update_all_ins(m)
  if m.ins == nil then
    return
  end
  for _, in_label in ipairs(m.ins) do
    local i = ins[in_label]
    if i ~= nil then
      i:update()
    end
  end
end

local function fire_and_propagate(in_label, initial_v)

  if initial_v == nil then initial_v = V_MAX/2 end

  dbg("----------")
  dbg("PATCH LAYOUT")
  dbg("----------")
  -- local fired_modules, link_map = exec_plan(out_label)
  local fired_modules, link_map = exec_plan_from_input(in_label)

  dbg("----------")
  dbg("TRIGGERED MODULES")
  dbg("----------")

  -- print("----------")

  for level, modules in ipairs(fired_modules) do
    for _, m in ipairs(modules) do
      -- REVIEW: should i reset all ins or only those of triggered links?
      reset_all_ins(m)
    end
  end

  for level, modules in ipairs(fired_modules) do
    -- dbgtab(fired_modules, level-1)


    for _, m in ipairs(modules) do
      dbg(m.fqid, level-1)
      if level ~= 1 then
        update_all_ins(m)
        m:process_ins()
      end

      for _, outbound_link in ipairs(link_map[m]) do

        local from = outbound_link[1]
        local to = outbound_link[2]
        dbg(from.id .. " -> " .. to.id, level-1)

        -- edge case of first module externally triggered (global norns clock)
        -- no real notion (for now) of input/output value handled by this module
        -- could be dealt w/ by using a superclock, but idk if i wann go there yet
        --
        -- FIXME: better way would be to define Trigger kind of Out that resets itself at the end of loop
        local v
        if level == 1 then
          v = initial_v
        else
          v = from.v
        end

        to:register(v)
      end

      :: NEXT_MODULE ::
    end
  end

  -- for _, i in ipairs(fired_ins) do
  --   dbg(i.id)

  --   local parent = i.parent
  --   parent:process_ins()
  -- end

  dbg("----------")
  DEBUG = false

end


-- local patch_matrix = {
--   -- outputs:
--   outputs = {
--     -- norns master clock: x1
--     mclock = {
--       -- quantized clocks
--     }
--     -- quantized clocks: x7
--     -- haleseq: x8 (stage gates) + 1 (press gate) + 5 (CV outs)
--   },
--   -- inputs:
--   inputs = {
--     -- quantized clocks: x1
--     -- haleseq: x8
--     -- outs: x5 (CV in) + x5 (VCA level)
--   },
-- }


-- ------------------------------------------------------------------------
-- state

local s_lattice

local g = nil
local has_grid = false

local g_knob = nil
local g_btn = nil

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


local function get_current_haleseq()
  local curr_page = page_list[pages.index]
  for i=1,NB_HALESEQS do
    if curr_page == "haleseq "..i then
      return haleseqs[i]
    end
  end
end

-- ------------------------------------------------------------------------
-- state - sequence values

local is_resetting = false

local prev_step = nil
local step = 1
local vstep = 1

local last_step_t = 0
local last_vstep_t = 0
local last_preset_t = 0

local stages = {}
local seqvals = {}

local V_MAX = 1000
local V_NB_OCTAVES = 10
local V_TRIG = 500


-- ------------------------------------------------------------------------
-- playback

local last_enc_note_play_t = 0

function all_notes_off()
  for _, o in ipairs(outputs) do
    o:nb_note_off()
  end
end


-- ------------------------------------------------------------------------
-- sequence

local next_step = nil
local clock_acum = 0
local reverse = false
local hold = false

local next_vstep = nil
local vclock_acum = 0
local vreverse = false

local mclock_acum = 0
local last_mclock_tick_t = 0

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

function mclock_tick(t, forced)
  if mclock_acum % (MCLOCK_DIVS / NB_BARS) == 0 then
    last_mclock_tick_t = os.clock()
  end
  if not forced then
    mclock_acum = mclock_acum + 1
  end

  -- propagate("norns_clock")
  fire_and_propagate("norns_clock")

  -- for _, h in ipairs(haleseqs) do
    -- local hclock = h.hclock()
    -- local vclock = h.vclock()
    -- if not forced then
    --   hclock:tick()
    --   vclock:tick()
    -- end

    -- local ticked = h:clock_tick(forced)
    -- local vticked = h:vclock_tick(forced)

    -- A / B / C / D
  --   if ticked then
  --     for vs=1,h:get_nb_vsteps() do
  --       local volts = h:get_current_play_volts(vs)
  --       local voiceId = vs
  --       local o = outputs[voiceId]
  --       o:nb_play_volts(volts)
  --     end
  --   end
  --   -- ABCD
  --   if ticked or vticked then
  --     local volts = h:get_current_mux_play_volts()
  --     local voiceId = h:get_nb_vsteps() + 1
  --     local o = outputs[voiceId]
  --     o:nb_play_volts(volts)
  --   end
  -- end

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

  -- stages[5].o = 2

  -- --------------------------------
  -- global params

  params:add_trigger("rnd_seqs", "Randomize Seqs")
  params:set_action("rnd_seqs",
                    function(_v)
                      for _, h in ipairs(haleseqs) do
                        local id = h:get_id()
                        params:set("rnd_seqs_"..id, 1)
                      end
                    end
  )


  local RND_MODES = {'Scale', 'Blip Bloop'}
  params:add_option("rnd_seq_mode", "Rnd Mode", RND_MODES, tab.key(RND_MODES, 'Scale'))
  params:set_action("rnd_seq_mode",
                    function(v)
                      if RND_MODES[v] == 'Scale' then
                        params:show("rnd_seq_root")
                      else
                        params:hide("rnd_seq_root")
                      end
                      _menu.rebuild_params()
                    end
  )
  params:add_option("rnd_seq_root", "Rnd Scale", musicutil.NOTE_NAMES, tab.key(musicutil.NOTE_NAMES, 'C'))


  -- --------------------------------
  -- modules

  norns_clock = NornsClock.init(ins, outs)
  quantized_clocks = QuantizedClock.init("global", MCLOCK_DIVS, CLOCK_DIV_DENOMS, ins, outs)

  for i = 1,NB_HALESEQS do
    local h = Haleseq.init(i, NB_STEPS, NB_VSTEPS, ins, outs, links)
    haleseqs[i] = h
  end

  for vs=1, NB_VSTEPS+1 do
    -- local label = output_nb_to_name(vs)
    local label = ""..vs
    outputs[vs] = Output.init(label, ins)
  end
  -- local mux_label = mux_output_nb_to_name(NB_VSTEPS)
  -- outputs[NB_VSTEPS+1] = Output.init(mux_label, ins)

  add_link("norns_clock", "quantized_clock_global")

  -- NB: creates links bewteen `quantized_clock_global` & `haleseq_1`
  params:set("clock_div_"..1, tab.key(CLOCK_DIVS, '1/16'))
  params:set("vclock_div_"..1, tab.key(CLOCK_DIVS, '1/2'))

  for vs=1, NB_VSTEPS do
    local label = output_nb_to_name(vs)
    local llabel = string.lower(label)
    add_link("haleseq_1_"..llabel, "output_"..vs)
  end
  local mux_label = mux_output_nb_to_name(NB_VSTEPS)
  local mux_llabel = string.lower(mux_label)
  -- add_link("haleseq_1_"..mux_llabel, "output_"..(NB_VSTEPS+1))


  -- TESTS
  -- add_link("haleseq_1_a", "haleseq_2_clock")
  add_link("haleseq_1_abcd", "haleseq_2_preset")
  add_link("haleseq_2_abcd", "output_5")


  -- --------------------------------

  nb:add_player_params()

  -- FIXME: can't be set at init like that...
  -- NB: bind multiplexed voice to first midi out if found
  -- local vs_mux = NB_VSTEPS + 1
  -- local p_id = get_first_nb_voice_midi_param_option_id(vs_mux)
  -- if p_id ~= nil then
  --   params:set("nb_voice_"..vs_mux, p_id)
  -- end

  -- NB: randomize seqs
  params:set("rnd_seqs", 1)

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
-- grid

local G_Y_PRESS = 8
local G_Y_KNOB = 2

function grid_redraw()
  g:all(0)

  local h = get_current_haleseq()
  if h ~= nil then
    h:grid_redraw(g)
  end

  g:refresh()
end

function grid_key(x, y, z)
  local h = get_current_haleseq()
  if h ~= nil then
    h:grid_key(x, y, z)
  end
end

-- ------------------------------------------------------------------------
-- controls

function enc(n, d)

  local h = get_current_haleseq()
  if h ~= nil then
    local id = h:get_id()

    if h:is_editing_knob() then
      h:knob(n, d)

      -- retrig note to get a preview
      if (math.abs(os.clock() - last_enc_note_play_t) >= PULSE_T) then
        local voiceId = h:knob_vs()
        local volts = h:knob_volts()

        local o = outputs[voiceId]
        o:nb_play_volts(volts)

        last_enc_note_play_t = os.clock()
      end
      return
    end

    if n == 2 then
      local sign = math.floor(d/math.abs(d))
      params:set("clock_div_"..id, params:get("clock_div_"..id) + sign)
      return
    end
    if n == 3 then
      local sign = math.floor(d/math.abs(d))
      params:set("vclock_div_"..id, params:get("vclock_div_"..id) + sign)
      return
    end

  end

  if n == 1 then
    -- params:set("clock_tempo", params:get("clock_tempo") + d)
    pages:set_index_delta(d, false)
    return
  end
end

-- ------------------------------------------------------------------------
-- screen

function redraw_clock_screen()
  local x = SCREEN_STAGE_W
  local y = SCREEN_STAGE_Y_OFFSET

  norns_clock.redraw(x, y, mclock_acum)

  x = x + SCREEN_STAGE_W * 5

  QuantizedClock.redraw(x, y, mclock_acum)

  x = x + SCREEN_STAGE_W * 5

  pulse_divider.redraw(x, y, mclock_acum)
end


function redraw()
  screen.clear()

  pages:redraw()

  screen.level(15)

  -- clock(s)
  -- screen.move(0, 8)
  -- screen.text(params:get("clock_tempo") .. " BPM ")
  -- screen.move(0, 18)
  -- screen.text(params:string("clock_div"))
  -- screen.move(0, 28)
  -- screen.text(params:string("vclock_div"))

  local curr_page = page_list[pages.index]
  if curr_page == "clock" then
    redraw_clock_screen()
  else
    local h = get_current_haleseq()
    if h ~= nil then
      h:redraw()
    end
  end

  screen.update()
end
