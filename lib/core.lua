

-- ------------------------------------------------------------------------
-- deps

local inspect = include("washi/lib/inspect")


-- ------------------------------------------------------------------------
-- debug

DEBUG = true

function dbg(v, level)
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

function dbgf(v, level)
  local prev_debug = DEBUG
  DEBUG = true
  dbg(v, level)
  DEBUG = prev_debug
end

-- ------------------------------------------------------------------------
-- math

function rnd(x)
  if x == 0 then
    return 0
  end
  if (not x) then
    x = 1
  end
  x = x * 100000
  x = math.random(x) / 100000
  return x
end

function srand(x)
  if not x then
    x = 0
  end
  math.randomseed(x)
end

function round(v)
  return math.floor(v+0.5)
end

function cos(x)
  return math.cos(math.rad(x * 360))
end

function sin(x)
  return -math.sin(math.rad(x * 360))
end

-- base1 modulo
function mod1(v, m)
  return ((v - 1) % m) + 1
end

function is_whole_number(v)
  return (v%1 == 0)
end

function mean(t)
  local sum = 0
  local count= 0
  for _, v in pairs(t) do
    sum = sum + v
    count = count + 1
  end
  return (sum / count)
end

function sum(t)
  local sum = 0
  for _, v in pairs(t) do
    sum = sum + v
  end
  return sum
end


-- ------------------------------------------------------------------------
-- tables

function tprint(t)
  print(inspect(t))
end

-- remove all element of table without changing its memory pointer
function tempty(t)
  for k, v in pairs(t) do
    t[k] = nil
  end
end

-- replace table value w/ other without changing its memory pointer
function treplace(t, newt)
  tempty(t)
  if newt == nil then
    return
  end
  for k, v in pairs(newt) do
    t[k] = v
  end
end

function tkeys(t)
  local t2 = {}
  for k, _ in pairs(t) do
    table.insert(t2, k)
  end
  return t2
end

function tvals(t)
  local t2 = {}
  for _, v in pairs(t) do
    table.insert(t2, v)
  end
  return t2
end

-- like `table.unpack` but supports maps
function tunpack(t)
  return table.unpack(tvals(t))
end

function set_insert(t, v)
  if not tab.contains(t, v) then
    table.insert(t, v)
  end
end

function sets_merge(t1, t2)
  for _, v in ipairs(t2) do
    set_insert(t1, v)
  end
end


-- ------------------------------------------------------------------------
-- coords

function are_coords_same(c, c2)
  return (c[1] == c2[1] and c[2] == c2[2])
end

function tab_contains_coord(t, c)
  for _, c2 in ipairs(t) do
    if are_coords_same(c, c2) then
      return true
    end
  end
  return false
end

function set_insert_coord(t, c)
  if not tab_contains_coord(t, c) then
    table.insert(t, c)
  end
end


-- ------------------------------------------------------------------------
-- time

function pulse_width_dur(width_pct, nb_bars)
  if nb_bars == nil then nb_bars = 1 end
  local bar_bpm = params:get("clock_tempo") / nb_bars

  local beat_dur = 60 / bar_bpm

  return width_pct * beat_dur / 100
end


-- ------------------------------------------------------------------------
-- output names

function output_nb_to_name(vs)
  return string.char(string.byte("A") + vs - 1)
end

function mux_output_nb_to_name(vs)
  local label = ""
  local nb_vsteps = vs
  for vs=1, nb_vsteps do
    label = label .. output_nb_to_name(vs)
  end
  return label
end


-- ------------------------------------------------------------------------
-- grid

function grid_level_radio(g, cond, redraw_counter)
  if g.nb_levels == 1 then
    if cond then
      return ( (redraw_counter % 5) == 0 ) and 10 or 0
    else
      return 10
    end
  end

  return (cond and 10 or 2)
end
