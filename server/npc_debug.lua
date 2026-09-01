LBVampire = LBVampire or {}


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetDebugConfig()

    return Config.NPCFeeding
        and Config.NPCFeeding.Debug
        or {}
end


---------------------------------------------------------
-- DISTANCE
---------------------------------------------------------

local function Distance(
    first,
    second
)
    if not first
        or not second then


        return math.huge
    end


    local x =
        first.x - second.x


    local y =
        first.y - second.y


    local z =
        first.z - second.z


    return math.sqrt(
        (x * x)
        +
        (y * y)
        +
        (z * z)
    )
end


---------------------------------------------------------
-- DEBUG DEPLETE
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:server:debugDepleteNPC',

    function(
        netId
    )
        if Config.Debug ~=
            true then


            return
        end


        local src =
            source


        -------------------------------------------------
        -- VAMPIRE
        -------------------------------------------------

        if not LBVampire.Vampires
            or not LBVampire.Vampires.IsVampire
            or not LBVampire.Vampires.IsVampire(
                src
            ) then


            return
        end


        netId =
            tonumber(
                netId
            )


        if not netId
            or netId <= 0 then


            return
        end


        -------------------------------------------------
        -- ENTITY
        -------------------------------------------------

        local entity =
            NetworkGetEntityFromNetworkId(
                netId
            )


        if not entity
            or entity == 0
            or not DoesEntityExist(
                entity
            ) then


            return
        end


        -------------------------------------------------
        -- DISTANCE
        -------------------------------------------------

        local playerPed =
            GetPlayerPed(
                src
            )


        if not playerPed
            or playerPed == 0 then


            return
        end


        local distance =
            Distance(

                GetEntityCoords(
                    playerPed
                ),

                GetEntityCoords(
                    entity
                )
            )


        local maximumDistance =
            tonumber(
                GetDebugConfig()
                    .MaxDistance
            )
            or 0.0


        if distance >
            maximumDistance then


            if Config.Debug then

                print(
                    (
                        '^3[LB-VAMPIRE]^7 NPC debug rejected | Distance: %.2f | Max: %.2f'
                    ):format(
                        distance,
                        maximumDistance
                    )
                )
            end


            return
        end


        -------------------------------------------------
        -- NPC BLOOD
        -------------------------------------------------

        if not LBVampire.NPCBlood
            or not LBVampire.NPCBlood.Set then


            return
        end


        local success,
            reason =
            LBVampire.NPCBlood.Set(
                netId,
                0
            )


        if success ~=
            true then


            if Config.Debug then

                print(
                    (
                        '^3[LB-VAMPIRE]^7 NPC debug depletion rejected | %s'
                    ):format(
                        tostring(
                            reason
                        )
                    )
                )
            end


            return
        end


        -------------------------------------------------
        -- REAL WITNESS PIPELINE
        -------------------------------------------------

        if LBVampire.NPCWitness
            and LBVampire.NPCWitness.HandleDepletion then


            LBVampire.NPCWitness.HandleDepletion(
                src,
                netId
            )
        end
    end
)