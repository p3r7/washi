


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

function mean(t)
  local sum = 0
  local count= 0
  for _, v in ipairs(t) do
    sum = sum + v
    count = count + 1
  end
  return (sum / count)
end

function sum(t)
  local sum = 0
  for _, v in ipairs(t) do
    sum = sum + v
  end
  return sum
end


-- ------------------------------------------------------------------------
-- tables

function tab_contains_coord(t, c)
  for _, c2 in ipairs(t) do
    if c[1] == c2[1] and c[2] == c2[2] then
      return true
    end
  end
  return false
end

function set_insert(t, v)
  if not tab.contains(t, v) then
    table.insert(t, v)
  end
end

function set_insert_coord(t, c)
  if not tab_contains_coord(t, c) then
    table.insert(t, c)
  end
end

function sets_merge(t1, t2)
  for _, v in ipairs(t2) do
    set_insert(t1, v)
  end
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
