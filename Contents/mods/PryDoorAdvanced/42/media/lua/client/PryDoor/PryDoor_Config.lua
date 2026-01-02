PryDoor = PryDoor or {}
PryDoor.Config = {
    VERSION = "4.1.0",
    DEBUG = false,

    KEYBIND = Keyboard.KEY_GRAVE,

    -- Tools in priority order
    TOOLS = {
        "Base.Crowbar",
        "Base.Axe",
        "Base.Screwdriver",
        "Base.Hammer",
        "Base.Wrench"
    },

    -- Tool bonuses
    TOOL_BONUS = {
        ["Base.Crowbar"] = 0.20,
        ["Base.Axe"] = 0.10,
        ["Base.Screwdriver"] = 0.00,
        ["Base.Hammer"] = -0.05,
        ["Base.Wrench"] = -0.10
    },

    -- Duration in ticks
    DURATION = {
        door = 150,
        garage = 180,
        window = 120,
        vehicle = 200
    },

    -- Max distance to target
    MAX_DISTANCE = 4,

    -- Base difficulty
    DIFFICULTY = {
        window = 0.90,
        door = 0.75,
        garage = 0.50,
        vehicle = 0.70
    },

    -- Minimum strength required
    MIN_STRENGTH = {
        window = 2,
        door = 4,
        garage = 6,
        vehicle = 3
    },

    -- Minimum skill required
    MIN_WOODWORK = 1,
    MIN_MECHANICS = 1,

    -- Noise radius
    NOISE_RADIUS = {
        window = 8,
        door = 12,
        garage = 20,
        vehicle = 15
    },

    -- Failure chances
    FAIL_CHANCE = {
        injury = 0.15
    },

    -- Fatigue cost
    FATIGUE_COST = {
        window = 0.05,
        door = 0.08,
        garage = 0.12,
        vehicle = 0.10
    },

    -- Messages
    MESSAGES = {
        NO_TOOL = "I need a prying tool!",
        NOTHING_LOCKED = "Nothing locked nearby.",
        TOO_WEAK = "I'm not strong enough!",
        TOO_TIRED = "Too tired to pry this.",
        TOO_UNSKILLED = "I don't have the skill to do this!",
        TOOL_INEFFECTIVE = "This tool can't pry that!",
        SUCCESS = "Got it open!",
        FAILED = "Ah shit! It didn't work!",
        INJURED = "Ouch! That hurt!"
    }
}

return PryDoor.Config
