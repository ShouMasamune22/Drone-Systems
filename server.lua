local QBCore = exports['qb-core']:GetCoreObject()

local lastStart = {}

local function CanUseDrone(src)
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return false, 'Karakter belum dimuat.'
    end

    local playerData = Player.PlayerData

    if Config.RestrictJobs then
        local job = playerData.job

        if not job or not Config.AllowedJobs[job.name] then
            return false, 'Pekerjaanmu tidak diizinkan menggunakan drone.'
        end

        if Config.RequireOnDuty and not job.onduty then
            return false, 'Kamu harus sedang bertugas.'
        end
    end

    if Config.RequiredItem then
        local item = Player.Functions.GetItemByName(
            Config.RequiredItem
        )

        if not item then
            return false, ('Kamu membutuhkan item %s.'):format(
                Config.RequiredItem
            )
        end
    end

    local now = os.time()
    local cooldown = Config.StartCooldownSeconds or 3

    if lastStart[src] and now - lastStart[src] < cooldown then
        return false, 'Tunggu sebentar sebelum menggunakan drone lagi.'
    end

    lastStart[src] = now

    return true
end

QBCore.Functions.CreateCallback(
    'cc-civilian-drone:server:canUse',
    function(source, cb)
        local allowed, reason = CanUseDrone(source)

        cb(allowed, reason)
    end
)

AddEventHandler('playerDropped', function()
    lastStart[source] = nil
end)