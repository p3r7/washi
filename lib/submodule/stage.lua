-- haleseq. stage

local Comparator = include("haleseq/lib/submodule/comparator")
local Out = include("haleseq/lib/submodule/out")

include("haleseq/lib/core")


-- ------------------------------------------------------------------------

local Stage = {}
Stage.__index = Stage


-- ------------------------------------------------------------------------
-- const

Stage.M_TIE = "tie"
Stage.M_RUN = "run"
Stage.M_SKIP = "skip"

local draw_modes = {Stage.M_TIE, Stage.M_RUN, Stage.M_SKIP}


-- ------------------------------------------------------------------------
-- constructors

function Stage.new(id, parent)
  local p = setmetatable({}, Stage)

  p.id = id
  p.parent = parent

  p.i = Comparator.new(id, parent)
  p.o = Out.new(id, parent)

  p.mode = Stage.M_RUN

  return p
end


-- ------------------------------------------------------------------------
-- getter/setter

function Stage:get_mode()
  return self.mode
end

function Stage:mode_cycle()
  local curr_mode_i = tab.key(draw_modes, self.mode)
  local mode_i = mod1(curr_mode_i+1, #draw_modes)
  self.mode = draw_modes[mode_i]
end

function Stage:tie()
  self.mode = Stage.M_TIE
end

function Stage:run()
  self.mode = Stage.M_RUN
end

function Stage:skip()
  self.mode = Stage.M_SKIP
end


-- ------------------------------------------------------------------------

return Stage
