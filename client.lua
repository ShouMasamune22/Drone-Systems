
local QBCore = exports['qb-core']:GetCoreObject()

local DroneAudioBank = 'DLC_BTL_DRONE_SOUNDS'
local DroneSoundId = -1

local Drone = {
    active = false,
    entity = nil,
    camera = nil,
    player = nil,
    wasFrozen = false,
    launch = nil,
    heading = 0.0,
    camYaw = 0.0,
    camPitch = -8.0,
    battery = 100.0,
    returning = false,
    photoCount = 0
}

local function Notify(message, kind)
    QBCore.Functions.Notify(message, kind or 'primary')
end

local function PlayDroneUISound(soundName, soundSet)
    PlaySoundFrontend(
        -1,
        soundName,
        soundSet or 'HUD_FRONTEND_DEFAULT_SOUNDSET',
        true
    )
end

local function StartDroneAudio()
    if DroneSoundId ~= -1 then
        return
    end

    if not Drone.entity or not DoesEntityExist(Drone.entity) then
        return
    end

    RequestScriptAudioBank(DroneAudioBank, false)

    DroneSoundId = GetSoundId()

    PlaySoundFromEntity(
        DroneSoundId,
        'FLIGHT_LOOP',
        Drone.entity,
        DroneAudioBank,
        false,
        0
    )
end

local function StopDroneAudio()
    if DroneSoundId ~= -1 then
        StopSound(DroneSoundId)
        ReleaseSoundId(DroneSoundId)
        DroneSoundId = -1
    end

    ReleaseNamedScriptAudioBank(DroneAudioBank)
end

local function PlayDroneStartSound()
    PlayDroneUISound(
        'SELECT',
        'HUD_FRONTEND_DEFAULT_SOUNDSET'
    )
end

local function PlayDroneStopSound()
    PlayDroneUISound(
        'BACK',
        'HUD_FRONTEND_DEFAULT_SOUNDSET'
    )
end

local function PlayDronePhotoSound()
    PlayDroneUISound(
        'Camera_Shoot',
        'Phone_SoundSet_Michael'
    )
end

local function PlayDroneWarningSound()
    PlayDroneUISound(
        'ERROR',
        'HUD_FRONTEND_DEFAULT_SOUNDSET'
    )
end

local function LoadDroneModel(modelName)
    local model = joaat(modelName)

    if not IsModelInCdimage(model)
        or not IsModelValid(model) then

        Notify(
            ('Model drone tidak valid: %s'):format(modelName),
            'error'
        )

        return nil
    end

    RequestModel(model)

    local timeout = GetGameTimer() + 10000

    while not HasModelLoaded(model) do
        Wait(25)

        if GetGameTimer() > timeout then
            Notify('Gagal memuat model drone.', 'error')
            return nil
        end
    end

    return model
end

local function DrawText2D(x, y, message, scale, centered)
    SetTextFont(4)
    SetTextScale(scale or 0.30, scale or 0.30)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    SetTextCentre(centered or false)

    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayText(x, y)
end

local function DestroyDroneCamera()
    if Drone.camera then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(Drone.camera, false)
        Drone.camera = nil
    end
end

local function CreateDroneCamera()
    Drone.camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    SetCamFov(Drone.camera, Config.CameraFov)
    SetCamActive(Drone.camera, true)

    RenderScriptCams(true, true, 250, true, true)
end

local function ForwardVector(heading)
    local angle = math.rad(heading)

    return vector3(
        -math.sin(angle),
        math.cos(angle),
        0.0
    )
end

local function RightVector(heading)
    local angle = math.rad(heading)

    return vector3(
        math.cos(angle),
        math.sin(angle),
        0.0
    )
end

local function DrawDroneHUD()
    if not Drone.entity or not DoesEntityExist(Drone.entity) then
        return
    end

    local coords = GetEntityCoords(Drone.entity)
    local distance = #(coords - Drone.launch)
    local altitude = coords.z - Drone.launch.z
    local battery = math.floor(Drone.battery + 0.5)

    DrawRect(
        0.5, 0.075,
        0.43, 0.105,
        7, 10, 16, 190
    )

    DrawText2D(
        0.5, 0.030,
        '~b~CIVILIAN FPV DRONE',
        0.38, true
    )

    DrawText2D(
        0.305, 0.059,
        ('BATTERY: %d%%'):format(battery),
        0.29
    )

    DrawText2D(
        0.420, 0.059,
        ('ALT: %.1fm'):format(altitude),
        0.29
    )

    DrawText2D(
        0.515, 0.059,
        ('RANGE: %.1fm'):format(distance),
        0.29
    )

    DrawText2D(
        0.610, 0.059,
        ('PHOTOS: %d'):format(Drone.photoCount),
        0.29
    )

    DrawText2D(
        0.5, 0.090,
        'WASD MOVE | SPACE/CTRL ALTITUDE | MOUSE FPV',
        0.27, true
    )

    DrawText2D(
        0.5, 0.111,
        'Q/E YAW | SCROLL ZOOM | ENTER PHOTO | BACKSPACE RETURN',
        0.25, true
    )

    if battery <= Config.LowBatteryPercent then
        DrawRect(
            0.5, 0.17,
            0.32, 0.035,
            140, 65, 0, 180
        )

        DrawText2D(
            0.5, 0.159,
            '~y~LOW BATTERY - RETURN TO LAUNCH POINT',
            0.31, true
        )
    end
end

local function TakePhotoMarker()
    if not Drone.active
        or Drone.returning
        or not Drone.entity
        or not DoesEntityExist(Drone.entity) then
        return
    end

    Drone.photoCount = Drone.photoCount + 1

    local coords = GetEntityCoords(Drone.entity)

    local streetHash = GetStreetNameAtCoord(
        coords.x,
        coords.y,
        coords.z
    )

    local street = GetStreetNameFromHashKey(streetHash)

    if not street or street == '' then
        street = 'Lokasi tidak diketahui'
    end

    PlayDronePhotoSound()

    SetNewWaypoint(coords.x, coords.y)

    if Config.PhotoNotify then
        Notify(
            ('Penanda foto #%d | %s | X: %.1f Y: %.1f Z: %.1f'):format(
                Drone.photoCount,
                street,
                coords.x,
                coords.y,
                coords.z
            ),
            'success'
        )
    end
end

local function CleanupDrone(returnToLaunch)
    if not Drone.active then
        return
    end

    Drone.active = false
    Drone.returning = false

    StopDroneAudio()
    DestroyDroneCamera()

    if Drone.entity and DoesEntityExist(Drone.entity) then
        if returnToLaunch
            and Config.ReturnOnStop
            and Drone.launch then

            SetEntityCoordsNoOffset(
                Drone.entity,
                Drone.launch.x,
                Drone.launch.y,
                Drone.launch.z + 1.0,
                false, false, false
            )
        end

        DeleteEntity(Drone.entity)
    end

    Drone.entity = nil

    if Drone.player and DoesEntityExist(Drone.player) then
        FreezeEntityPosition(
            Drone.player,
            Drone.wasFrozen
        )
    end

    Drone.player = nil

    PlayDroneStopSound()
end

local function ReturnDrone()
    if not Drone.active or Drone.returning then
        return
    end

    Drone.returning = true

    Notify('Drone sedang kembali ke titik peluncuran.')

    CreateThread(function()
        while Drone.active
            and Drone.entity
            and DoesEntityExist(Drone.entity) do

            local coords = GetEntityCoords(Drone.entity)

            local target = vector3(
                Drone.launch.x,
                Drone.launch.y,
                Drone.launch.z + 1.0
            )

            local difference = target - coords
            local distance = #difference

            if distance <= 1.5 then
                break
            end

            local step = math.min(
                Config.ReturnSpeed * GetFrameTime(),
                distance
            )

            local nextCoords = coords
                + (difference / distance) * step

            SetEntityCoordsNoOffset(
                Drone.entity,
                nextCoords.x,
                nextCoords.y,
                nextCoords.z,
                false, false, false
            )

            Wait(0)
        end

        if Drone.active then
            CleanupDrone(false)

            Notify(
                'Drone berhasil dihentikan.',
                'success'
            )
        end
    end)
end

local function UpdateDroneMovement()
    if not Drone.entity
        or not DoesEntityExist(Drone.entity)
        or not Drone.camera then
        return
    end

    local mouseX = GetDisabledControlNormal(0, 1)
    local mouseY = GetDisabledControlNormal(0, 2)

    Drone.heading = Drone.heading
        - mouseX * Config.MouseSensitivity * 10.0

    Drone.camYaw = Drone.heading

    Drone.camPitch = math.max(
        Config.PitchMin,
        math.min(
            Config.PitchMax,
            Drone.camPitch
                - mouseY * Config.MouseSensitivity * 10.0
        )
    )

    local deltaTime = GetFrameTime()

    if IsDisabledControlPressed(0, Config.Controls.YawLeft) then
        Drone.heading = Drone.heading
            - Config.YawSpeed * deltaTime
    end

    if IsDisabledControlPressed(0, Config.Controls.YawRight) then
        Drone.heading = Drone.heading
            + Config.YawSpeed * deltaTime
    end

    Drone.camYaw = Drone.heading

    local coords = GetEntityCoords(Drone.entity)
    local movement = vector3(0.0, 0.0, 0.0)

    local forward = ForwardVector(Drone.heading)
    local right = RightVector(Drone.heading)

    if IsDisabledControlPressed(0, Config.Controls.Forward) then
        movement = movement + forward
    end

    if IsDisabledControlPressed(0, Config.Controls.Backward) then
        movement = movement - forward
    end

    if IsDisabledControlPressed(0, Config.Controls.Left) then
        movement = movement - right
    end

    if IsDisabledControlPressed(0, Config.Controls.Right) then
        movement = movement + right
    end

    if #movement > 0.0 then
        movement = movement / #movement

        coords = coords
            + movement * Config.FlySpeed * deltaTime
    end

    if IsDisabledControlPressed(0, Config.Controls.Up) then
        coords = coords
            + vector3(0.0, 0.0, Config.VerticalSpeed * deltaTime)
    end

    if IsDisabledControlPressed(0, Config.Controls.Down) then
        coords = coords
            - vector3(0.0, 0.0, Config.VerticalSpeed * deltaTime)
    end

    local distance = #(coords - Drone.launch)
    local altitude = coords.z - Drone.launch.z

    if distance <= Config.MaxDistance
        and altitude <= Config.MaxHeightAboveLaunch
        and altitude >= Config.MinHeightAboveLaunch then

        SetEntityCoordsNoOffset(
            Drone.entity,
            coords.x,
            coords.y,
            coords.z,
            false, false, false
        )
    end

    SetEntityHeading(Drone.entity, Drone.heading)

    if IsDisabledControlJustPressed(0, Config.Controls.ZoomIn) then
        SetCamFov(
            Drone.camera,
            math.max(
                Config.MinFov,
                GetCamFov(Drone.camera) - 5.0
            )
        )
    end

    if IsDisabledControlJustPressed(0, Config.Controls.ZoomOut) then
        SetCamFov(
            Drone.camera,
            math.min(
                Config.MaxFov,
                GetCamFov(Drone.camera) + 5.0
            )
        )
    end

    if IsDisabledControlJustPressed(0, Config.Controls.Photo) then
        TakePhotoMarker()
    end

    local cameraCoords = GetOffsetFromEntityInWorldCoords(
        Drone.entity,
        0.0, 0.12, 0.08
    )

    SetCamCoord(
        Drone.camera,
        cameraCoords.x,
        cameraCoords.y,
        cameraCoords.z
    )

    SetCamRot(
        Drone.camera,
        Drone.camPitch,
        0.0,
        Drone.camYaw,
        2
    )
end

local function StartDrone()
    if Drone.active then
        Notify('Drone sudah aktif.', 'error')
        return
    end

    QBCore.Functions.TriggerCallback(
        'cc-civilian-drone:server:canUse',
        function(allowed, reason)
            if not allowed then
                Notify(
                    reason or 'Kamu tidak dapat menggunakan drone.',
                    'error'
                )
                return
            end

            local ped = PlayerPedId()

            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
                Notify(
                    'Keluar dari kendaraan dan pastikan karaktermu masih hidup.',
                    'error'
                )
                return
            end

            local model = LoadDroneModel(Config.Model)

            if not model then
                return
            end

            Drone.player = ped
            Drone.wasFrozen = IsEntityPositionFrozen(ped)
            Drone.launch = GetEntityCoords(ped)
            Drone.heading = GetEntityHeading(ped)
            Drone.camYaw = Drone.heading
            Drone.camPitch = -8.0
            Drone.battery = 100.0
            Drone.photoCount = 0
            Drone.returning = false

            local spawnCoords = GetOffsetFromEntityInWorldCoords(
                ped,
                0.0, 1.2, 1.5
            )

            Drone.entity = CreateObject(
                model,
                spawnCoords.x,
                spawnCoords.y,
                spawnCoords.z,
                false, false, false
            )

            SetModelAsNoLongerNeeded(model)

            if not Drone.entity
                or not DoesEntityExist(Drone.entity) then

                Drone.entity = nil

                Notify(
                    'Drone gagal dibuat. Periksa Config.Model.',
                    'error'
                )

                return
            end

            SetEntityHeading(Drone.entity, Drone.heading)
            SetEntityCollision(Drone.entity, false, false)
            SetEntityHasGravity(Drone.entity, false)
            SetEntityInvincible(Drone.entity, true)
            SetEntityDynamic(Drone.entity, false)

            FreezeEntityPosition(ped, true)

            Drone.active = true

            CreateDroneCamera()

            StartDroneAudio()
            PlayDroneStartSound()

            Notify(
                'Drone sipil aktif. Gerakkan mouse untuk mengendalikan arah FPV.',
                'success'
            )

            CreateThread(function()
                local lastBatteryTick = GetGameTimer()
                local warnedLowBattery = false

                while Drone.active do
                    Wait(0)

                    if not Drone.entity
                        or not DoesEntityExist(Drone.entity) then

                        CleanupDrone(false)
                        break
                    end

                    DisableAllControlActions(0)

                    EnableControlAction(0, 245, true)
                    EnableControlAction(0, 200, true)
                    EnableControlAction(0, 202, true)

                    if IsDisabledControlJustPressed(
                        0,
                        Config.Controls.Stop
                    ) then
                        ReturnDrone()
                    end

                    if Drone.returning then
                        local coords = GetEntityCoords(Drone.entity)

                        if Drone.camera then
                            SetCamCoord(
                                Drone.camera,
                                coords.x,
                                coords.y,
                                coords.z + 0.1
                            )

                            SetCamRot(
                                Drone.camera,
                                Drone.camPitch,
                                0.0,
                                Drone.camYaw,
                                2
                            )
                        end
                    else
                        UpdateDroneMovement()
                    end

                    if not Drone.returning
                        and GetGameTimer() - lastBatteryTick >= 1000 then

                        local flightSeconds = math.max(
                            1,
                            Config.BatterySeconds
                        )

                        Drone.battery = math.max(
                            0.0,
                            Drone.battery - (100.0 / flightSeconds)
                        )

                        lastBatteryTick = GetGameTimer()

                        if Drone.battery <= Config.LowBatteryPercent
                            and not warnedLowBattery then

                            warnedLowBattery = true

                            PlayDroneWarningSound()

                            Notify(
                                'Baterai rendah. Segera kembali ke titik peluncuran.',
                                'error'
                            )

                            if Config.AutoReturnAtBatteryLow then
                                ReturnDrone()
                            end
                        end

                        if Drone.battery <= 0.0 then
                            ReturnDrone()
                        end
                    end

                    DrawDroneHUD()
                end
            end)
        end
    )
end

RegisterCommand(Config.Command, function()
    StartDrone()
end, false)

RegisterCommand(Config.StopCommand, function()
    if Drone.active then
        ReturnDrone()
    else
        Notify('Drone tidak sedang aktif.', 'error')
    end
end, false)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    CleanupDrone(false)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Drone.active = false
    Drone.returning = false

    StopDroneAudio()
    DestroyDroneCamera()

    if Drone.entity and DoesEntityExist(Drone.entity) then
        DeleteEntity(Drone.entity)
    end

    if Drone.player and DoesEntityExist(Drone.player) then
        FreezeEntityPosition(
            Drone.player,
            Drone.wasFrozen
        )
    end

    Drone.entity = nil
    Drone.player = nil
end)
