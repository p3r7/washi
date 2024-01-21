
local bit32 = {}

function bit32.band(a,b)
  return(a&b)
end

function bit32.bor(a,b)
  return(a|b)
end

function bit32.lshift(a,b)
  return(a<<b)
end

return bit32
