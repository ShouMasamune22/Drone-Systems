Config = {}

Config.Command = 'drone'
Config.StopCommand = 'dronestop'
Config.RestrictJobs = false

Config.AllowedJobs = {
    photographer = true,
    realestate = true
}

Config.RequireOnDuty = false
Config.RequiredItem = false

Config.Model = 'ch_prop_casino_drone_01a'

Config.MaxDistance = 300.0
Config.MaxHeightAboveLaunch = 150.0
Config.MinHeightAboveLaunch = 1.0

Config.FlySpeed = 14.0
Config.VerticalSpeed = 7.0
Config.YawSpeed = 100.0

Config.CameraFov = 60.0
Config.MinFov = 25.0
Config.MaxFov = 85.0
Config.MouseSensitivity = 8.0
Config.PitchMin = -85.0
Config.PitchMax = 30.0

Config.BatterySeconds = 420
Config.LowBatteryPercent = 15
Config.AutoReturnAtBatteryLow = true

Config.ReturnOnStop = true
Config.ReturnSpeed = 15.0

Config.Controls = {
    Forward = 32,  -- W
    Backward = 33, -- S
    Left = 34,     -- A
    Right = 35,    -- D

    Up = 22,       -- SPACE
    Down = 36,     -- LEFT CTRL

    YawLeft = 44,  -- Q
    YawRight = 38, -- E

    Stop = 177,    -- BACKSPACE

    ZoomIn = 15,   -- Mouse wheel up
    ZoomOut = 14,  -- Mouse wheel down

    Photo = 191    -- ENTER
}

Config.StartCooldownSeconds = 3
Config.PhotoNotify = true