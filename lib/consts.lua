

-- ------------------------------------------------------------------------
-- SCREEN & GRID

if seamstress then
  FPS = 60
  -- FPS = 15
else
  FPS = 15
end

GRID_FPS = 15


-- ------------------------------------------------------------------------
-- clock - seconds

SCLOCK_FREQ = 1/20

TRIG_S = 1/10

PULSE_T = 1/10

NANA_TRIG_DRAW_T = 1/5
LINK_TRIG_DRAW_T = 1/5


-- ------------------------------------------------------------------------
-- (quantized) clock - bars

MCLOCK_DIVS = 64
NB_BARS = 2

CLOCK_DIV_DENOMS = {1, 2, 4, 8, 16, 32, 64}
CLOCK_DIVS = {'off', '1/1', '1/2', '1/4', '1/8', '1/16', '1/32', '1/64'}


-- ------------------------------------------------------------------------
-- LFO / RVG / SSG...

LFO_COMPUTATIONS_PER_S = 30

LFO_MIN_RATE = 0.001
LFO_MAX_RATE = 5.0
LFO_DEFAULT_RATE = 0.5

LFO_PHASES = {0, 45, 90, 135, 180, 225, 270}


-- ------------------------------------------------------------------------
-- sequenced values

V_MAX = 1000
V_DEFAULT_THRESHOLD = 200

V_COMPUTE_MODE_GLOBAL = 0
V_COMPUTE_MODE_MEAN = 1
V_COMPUTE_MODE_SUM = 2
V_COMPUTE_MODE_AND = 3
V_COMPUTE_MODE_OR = 4

V_THRESHOLD_MODE_GLOBAL = 0
V_THRESHOLD_MODE_OWN = 0


-- ------------------------------------------------------------------------
-- prog / seq

NB_STEPS = 8
NB_VSTEPS = 4


-- ------------------------------------------------------------------------
-- screen - general

SCREEN_W = 128
SCREEN_H = 64


-- ------------------------------------------------------------------------
-- screen - paperface

-- local SCREEN_STAGE_Y_OFFSET = 12
SCREEN_STAGE_Y_OFFSET = 1

SCREEN_LEVEL_LABEL = 1
SCREEN_LEVEL_LABEL_SPE = 5

SCREEN_LEVEL_BANANA = 10
SCREEN_LEVEL_BANANA_TAMED = 2

SCREEN_LEVEL_LINK = 5
SCREEN_LEVEL_LINK_TAMED = 1

SCREEN_LW_LINK = 1
SCREEN_LW_LINK_FOCUSED = 1.5

if norns then
  SCREEN_STAGE_W = 15
  SCREEN_LABEL_Y_OFFSET = SCREEN_STAGE_W - 8
end
if seamstress then
  SCREEN_LABEL_Y_OFFSET = 2
end

DRAW_M_NORMAL = nil
DRAW_M_TAME = 'tamed'
DRAW_M_FOCUS = 'focus'

COLOR_BANANA_CV_IN = {128, 128, 128}
COLOR_BANANA_TRIG_IN = {255, 255, 255}
COLOR_BANANA_CV_OUT = {0, 0, 255}
COLOR_BANANA_TRIG_OUT = {255, 0, 0}


-- ------------------------------------------------------------------------
-- panel grid

SCREEN_STAGE_W = 9
SCREEN_STAGE_X_NB = 14
SCREEN_STAGE_Y_NB = 7


-- ------------------------------------------------------------------------
-- grid

SMALLEST_GRID_W = 8


-- ------------------------------------------------------------------------
-- INTERACTION MODES

A_ADDED = 'added'
A_REMOVED = 'removed'

M_PLAY = 'play'
M_SCOPE = 'scope'
M_LINK = 'link'
M_EDIT = 'edit'
