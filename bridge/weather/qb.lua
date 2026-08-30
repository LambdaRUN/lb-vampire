LBVampire = LBVampire or {}
LBVampire.Weather = LBVampire.Weather or {}

LBVampire.Weather.Current = nil
LBVampire.Weather.Ready = false


local function NormalizeWeather(weather)
    if not weather then
        return nil
    end

    return string.upper(
        tostring(weather)
    )
end


local function RequestWeatherSync()
    if GetResourceState(
        'qb-weathersync'
    ) ~= 'started' then

        return false
    end

    TriggerServerEvent(
        'qb-weathersync:server:RequestStateSync'
    )

    return true
end


function LBVampire.Weather.GetCurrent()
    return LBVampire.Weather.Current
end


function LBVampire.Weather.IsReady()
    return LBVampire.Weather.Ready == true
end


function LBVampire.Weather.IsReduced(weather)
    weather =
        NormalizeWeather(weather)

    if not weather then
        return false
    end

    if not Config.Sun
        or not Config.Sun.Weather
        or not Config.Sun.Weather.Reduced then

        return false
    end

    return Config.Sun
        .Weather
        .Reduced[weather] == true
end


RegisterNetEvent(
    'qb-weathersync:client:SyncWeather',
    function(newWeather)
        newWeather =
            NormalizeWeather(
                newWeather
            )

        if not newWeather then
            return
        end

        LBVampire.Weather.Current =
            newWeather

        LBVampire.Weather.Ready =
            true

        if Config.Debug then
            print(
                (
                    '^5[LB-VAMPIRE]^7 Weather sync: %s'
                ):format(
                    newWeather
                )
            )
        end
    end
)


--
-- Normal character login
--
RegisterNetEvent(
    'QBCore:Client:OnPlayerLoaded',
    function()
        CreateThread(function()
            Wait(1000)

            RequestWeatherSync()

            --
            -- İlk request timing yüzünden kaçarsa
            -- ikinci kez doğrula.
            --
            Wait(3000)

            if not LBVampire.Weather.Ready then
                RequestWeatherSync()
            end
        end)
    end
)


--
-- LB-VAMPIRE oyuncu zaten online iken
-- restart edilmiş olabilir.
--
CreateThread(function()
    local attempts = 0

    while attempts < 10 do
        attempts =
            attempts + 1

        Wait(1000)

        if RequestWeatherSync() then
            break
        end
    end

    --
    -- İlk request'ten birkaç saniye sonra
    -- hâlâ state yoksa tekrar iste.
    --
    Wait(3000)

    if not LBVampire.Weather.Ready then
        RequestWeatherSync()
    end
end)


--
-- qb-weathersync tek başına restart edilirse
-- LB-VAMPIRE tekrar state istesin.
--
AddEventHandler(
    'onClientResourceStart',
    function(resourceName)
        if resourceName ~= 'qb-weathersync' then
            return
        end

        LBVampire.Weather.Ready =
            false

        LBVampire.Weather.Current =
            nil

        CreateThread(function()
            Wait(1000)

            RequestWeatherSync()
        end)
    end
)