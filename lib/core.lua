


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
