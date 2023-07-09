

-- ------------------------------------------------------------------------
-- SCREEN & GRID

FPS = 15
GRID_FPS = 15


-- ------------------------------------------------------------------------
-- clock

MCLOCK_DIVS = 64
NB_BARS = 2

CLOCK_DIV_DENOMS = {1, 2, 4, 8, 16, 32, 64}
CLOCK_DIVS = {'off', '1/1', '1/2', '1/4', '1/8', '1/16', '1/32', '1/64'}

TRIG_S = 0.01

PULSE_T = 0.02 -- FIXME: don't use os.clock() but a lattice clock for stable gate beahvior

NANA_TRIG_DRAW_T = 0.04
LINK_TRIG_DRAW_T = 0.04


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

-- local SCREEN_STAGE_W = 15
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

DRAW_M_NORMAL = nil
DRAW_M_TAME = 'tamed'
DRAW_M_FOCUS = 'focus'


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
