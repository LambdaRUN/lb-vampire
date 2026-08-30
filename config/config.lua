Config = {}

Config.Debug = true

Config.Framework = 'qb'

Config.AdminPermission = 'admin'

Config.Blood = {
    Max = 100,
    Default = 100,

    NaturalDrain = {
        Enabled = true,

        -- Production:
        -- 1 Blood / 8 dakika
        Interval = 8 * 60 * 1000,

        Amount = 1
    },

    Thresholds = {
        Low = 25,
        Critical = 10
    }
}


Config.Sun = {
    Enabled = true,

    CheckInterval = 2000,

    DayStartHour = 7,
    DayEndHour = 20,

    Drain = {
        ServerTick = 5000,

        DirectInterval = 60 * 1000,
        ReducedInterval = 5 * 60 * 1000
    },

    Weather = {
        Provider = 'qb',

        Reduced = {
            FOGGY = true,
            OVERCAST = true,
            CLOUDS = true,
            CLEARING = true,
            RAIN = true,
            THUNDER = true,
            SMOG = true,

            SNOW = true,
            BLIZZARD = true,
            SNOWLIGHT = true,
            XMAS = true,
            HALLOWEEN = true
        }
    },

    Vehicle = {
        Enabled = true,

        -- 8  = Motorcycle
        -- 13 = Bicycle
        -- 14 = Boat
        OpenClasses = {
            [8] = true,
            [13] = true,
            [14] = true
        },

        -- Custom araçlar için ileride override.
        -- ['modelname'] = true  -> SAFE
        -- ['modelname'] = false -> açık araç
        ModelOverrides = {}
    },

        Cover = {
        Enabled = true,

        -- Cover ne sıklıkla kontrol edilecek.
        CheckInterval = 1000,

        -- Oyuncunun ne kadar yukarısına bakacağız.
        RayHeight = 30.0,

        -- World geometry + objects.
        -- World = 1
        -- Objects = 16
        TraceFlags = 17,

        OptionFlags = 7,

        -- 5 ray'den en az 3'ü bir yüzeye çarparsa
        -- gerçekten fiziksel cover var kabul edeceğiz.
        RequiredHits = 3,

        Offsets = {
            { x =  0.00, y =  0.00 },
            { x =  0.40, y =  0.00 },
            { x = -0.40, y =  0.00 },
            { x =  0.00, y =  0.40 },
            { x =  0.00, y = -0.40 }
        }
    }
}

Config.HumanBlood = {
    Max = 100,
    Default = 100,

    Recovery = {
        Enabled = true,

        Interval = 60 * 1000,
        Amount = 5
    },

    Runtime = {
        SaveInterval = 45 * 1000
    },

    HUD = {
        Enabled = true,

        -- Sağlıklı insanın ekranında gereksiz HUD olmasın.
        ShowAtFull = false,

        -- Feeding başladığı anda 100 olsa bile göster.
        ShowWhileFeeding = true,

        Thresholds = {
            Low = 70,
            Critical = 40,
            Severe = 20
        }
    },

    Consequences = {
        Enabled = true,

        ZeroBlood = {
            Enabled = true,

            SetHealthToZero = true,

            Notification =
                'Aşırı kan kaybı nedeniyle bilincini kaybettin.'
        }
    }
}

Config.Items = Config.Items or {}

Config.Items.BloodBag = {
    Enabled = true,

    Name = 'lb_bloodbag',

    -- Torbanın varsayılan LB-VAMPIRE kan kapasitesi.
    DefaultAmount = 35,

    -- Bir torbada tutulabilecek maksimum miktar.
    MaxAmount = 35,

    -- 7 gün.
    ShelfLife = 7 * 24 * 60 * 60,

    VampireUse = true,

    HumanUse = true,

    -- Şimdilik güvenli ve basit:
    -- İnsan yalnız kendi kan grubuyla birebir aynı
    -- torbayı kullanabilir.
    --
    -- Daha sonra medical sisteminde:
    -- ABO/Rh compatible transfusion yapabiliriz.
    HumanCompatibilityMode = 'exact',

    -- Başka oyuncuya export üzerinden kan verilecekse
    -- maksimum server-side mesafe.
    AdministrationDistance = 3.0
}

Config.Persistence = {
    SaveInterval = 60000
}

Config.HUD = {
    Enabled = true,

    Provider = 'standalone',

    EditorCommand = 'vamhud',

    KvpKey = 'lb-vampire:hud-layout:v1',

    Limits = {
        MinScale = 0.65,
        MaxScale = 1.50,

        MinOpacity = 0.35,
        MaxOpacity = 1.00
    },

    Elements = {
        Blood = {
            Enabled = true,
            EditorVisible = true,

            Left = 1.8,
            Bottom = 7.0,

            Scale = 1.0,
            Opacity = 1.0
        },

        -- Şimdilik render edilmiyor.
        -- Sun fazında Enabled ve EditorVisible true olacak.
        Sun = {
            Enabled = true,
            EditorVisible = true,

            Left = 6.0,
            Bottom = 7.0,

            Scale = 1.0,
            Opacity = 1.0
        },

        HumanBlood = {
            Enabled = true,
            EditorVisible = true,

            Left = 1.8,
            Bottom = 7.0,
            
            Scale = 1.0,
            Opacity = 1.0
        }
    }
}

Config.NPCFeeding = {
    Enabled = true,

    -----------------------------------------------------
    -- TARGET
    -----------------------------------------------------

    Interaction = {
        Distance = 2.5,

        Label = 'Beslen',

        Icon = 'fas fa-tint'
    },

    -----------------------------------------------------
    -- BLOOD
    -----------------------------------------------------

    Blood = {
        Max = 100,
        Default = 100,

        Recovery = {
            Enabled = true,

            -- NPC yaşıyorsa:
            -- 60 saniyede +5.
            Interval = 60 * 1000,
            Amount = 5
        }
    },

    -----------------------------------------------------
    -- FEEDING
    -----------------------------------------------------

    Transfer = {
        Enabled = true,

        Duration = 30 * 1000,
        TickInterval = 500,

        GainRatio = 1.0
    },

    -----------------------------------------------------
    -- STATUS UI
    --
    -- Mevcut feeding status kartını kullanacağız.
    -----------------------------------------------------

    StatusUI = {
        Enabled = true,

        Thresholds = {
            Low = 70,
            Critical = 40,
            Severe = 20
        }
    },

    -----------------------------------------------------
    -- NPC REACTIONS
    -----------------------------------------------------

    Behavior = {
        Enabled = true,

        AfterFeeding = {
            HealthyThreshold = 40,

            HealthyRagdoll = {
                Min = 1200,
                Max = 2500
            },

            WeakRagdoll = {
                Min = 3500,
                Max = 6500
            },

            FleeAfterRecovery = true,

            FleeDistance = 120.0,
            FleeDuration = 15000
        },

        BloodEmpty = {
            KillNPC = true,

            -- 0'a düşmüş NPC artık toparlanmaz.
            PermanentDrained = true
        }
    },

    -----------------------------------------------------
    -- WITNESSES
    -----------------------------------------------------

    Witness = {
        Enabled = true,

        Radius = 25.0,

        -- Kurban hariç maksimum kaç ambient NPC
        -- witness hesabına alınsın.
        MaximumWitnesses = 8,

        Panic = true,

        Caller = true,

        CallerDelay = {
            Min = 4000,
            Max = 10000
        }
    },

    -----------------------------------------------------
    -- DISPATCH
    -----------------------------------------------------

    Dispatch = {
        Enabled = true,

        BaseChance = 35,

        MinChance = 5,
        MaxChance = 95,

        WitnessBonus = 25,

        AdditionalWitnessBonus = 5,
        MaxWitnessBonus = 40,

        BusyArea = {
            Radius = 40.0,
            MinimumPeds = 4,

            Bonus = 15
        },

        Night = {
            Enabled = true,

            StartHour = 22,
            EndHour = 5,

            Modifier = -15
        },

        Secluded = {
            Enabled = true,

            Radius = 45.0,

            MaximumPeds = 1,
            MaximumVehicles = 1,

            Modifier = -20
        },

        AnonymousDelay = {
            Min = 12000,
            Max = 25000
        }
    },

    -----------------------------------------------------
    -- RUNTIME CLEANUP
    -----------------------------------------------------

    Runtime = {
        CleanupInterval = 60 * 1000,

        -- Entity artık yoksa state silinir.
        RemoveMissingEntities = true
    }
}

Config.Feeding = {
    Enabled = true,

    RequestDistance = 2.5,
    AcceptDistance = 3.0,

    ConsentTimeout = 15 * 1000,
    RequestCooldown = 3 * 1000,

    AllowVampireTarget = false,

    DebugCommands = true,

    Transfer = {
        Enabled = true,

        -- HumanBlood 100 -> 0 tam 30 saniye.
        Duration = 30 * 1000,

        -- HUD güncellemesi ve server transfer tick'i.
        -- 500ms = saniyede 2 güncelleme.
        TickInterval = 500,

        -- 1 HumanBlood kaybı =
        -- 1 Vampire Blood kazanımı.
        GainRatio = 1.0
    },

    Animation = {
        Enabled = true,

        -----------------------------------------------------
        -- FEMALE / HUMAN tarafının anim dictionary'si
        -- farklı olduğu için tek Dictionary mantığı artık
        -- yeterli değil.
        -----------------------------------------------------

        HumanDictionary = 'genesismods_kissme@kissfemale9',
        Human = 'kissfemale9',

        VampireDictionary = 'genesismods_kissme@kissmale9',
        Vampire = 'kissmale9',

        -- LOOP
        Flag = 1,

        -----------------------------------------------------
        -- Bu paired anim zaten kendi hizasını kullanıyor.
        -----------------------------------------------------

        FacePartner = false,
        FaceDuration = 0,

        DisableControls = true,

        -----------------------------------------------------
        -- çiftpoz10a attach edilen taraf.
        --
        -- Senin verdiğin emote yapısında:
        --
        -- çiftpoz10a = kissmale9
        -- Attachto = true
        --
        -- O yüzden HUMAN tarafını VAMPIRE pedine bağlıyoruz.
        -----------------------------------------------------

        Attach = {
            Enabled = true,

            Role = 'HUMAN',

            Bone = 0,

            X = -0.35,
            Y = 0.0,
            Z = 0.0,

            RotX = 0.0,
            RotY = 0.0,
            RotZ = 0.0
        }
    },

    Interrupts = {
        Enabled = true,

        -- Server kontrolü
        ServerCheckInterval = 250,

        MaxDistance = 3.5,

        CancelOnDeath = true,
        CancelOnLastStand = true,

        CancelInVehicle = true,

        -- Tek server tick'i arasında bu kadar büyük
        -- konum değişimi teleport kabul edilir.
        TeleportDistance = 5.0,

        -- Client kontrolü
        ClientCheckInterval = 100,

        CancelOnDamage = true,
        CancelOnRagdoll = true
    },

    StatusUI = {
        Enabled = true,

        UpdateInterval = 250,

        StopKey = 'X',

        Notifications = {
            Critical = true,
            Severe = true
        }
    }
}

Config.BloodAffinity = {
    Enabled = true,

    BloodTypes = {
        'O+',
        'O-',
        'A+',
        'A-',
        'B+',
        'B-',
        'AB+',
        'AB-'
    },

    Multipliers = {
        -- Vampirin birebir tercih ettiği kan.
        Exact = 1.20,

        -- Örn tercih A+ ise A-
        SameABO = 1.08,

        -- Diğer tüm kanlar.
        Other = 1.00
    },

    NotifyExactMatch = true
}

Config.Interactions = {
    Target = {
        Enabled = true,

        -- auto:
        -- qb-target varsa onu kullanır.
        --
        -- ileride:
        -- ox_target
        -- custom
        -- none
        Provider = 'auto',

        Feeding = {
            Label = 'Beslenme İsteği Gönder',
            Icon = 'fas fa-tint',

            Distance = 2.5
        }
    }
}

Config.Dispatch = {
    Enabled = true,

    -----------------------------------------------------
    -- auto
    -- ps
    -- qb
    -- none
    -----------------------------------------------------

    Provider = 'auto',

    -----------------------------------------------------
    -- AUTO
    --
    -- ps-dispatch çalışıyorsa önce onu kullan.
    -- Yoksa stock QB fallback.
    -----------------------------------------------------

    Auto = {
        PreferPS = true
    },

    -----------------------------------------------------
    -- PS-DISPATCH
    -----------------------------------------------------

    PS = {
        Resource = 'ps-dispatch',

        -------------------------------------------------
        -- Bunlar ps-dispatch'in mevcut Config.Blips
        -- profillerini kullanıyor.
        --
        -- Dolayısıyla ps-dispatch core edit gerekmiyor.
        -------------------------------------------------

        Profiles = {
            NPCDeath = {
                CodeName = 'civdead',
                Code = '10-66',

                Icon = 'fas fa-person-falling',

                Priority = 2,

                Jobs = {
                    'leo'
                }
            },

            BeastCall = {
                CodeName = 'hunting',
                Code = '10-54',

                Icon = 'fas fa-paw',

                Priority = 2,

                Jobs = {
                    'leo'
                }
            },

            Suspicious = {
                CodeName = 'civdead',
                Code = '10-66',

                Icon = 'fas fa-triangle-exclamation',

                Priority = 2,

                Jobs = {
                    'leo'
                }
            }
        }
    },

    -----------------------------------------------------
    -- STOCK QB
    -----------------------------------------------------

    QB = {
        PoliceResource = 'qb-policejob',
        PhoneResource = 'qb-phone'
    }
}


Config.Logging = {
    Enabled = true,

    -- console | qb | both
    Provider = 'console',

    QBLogName = 'default'
}