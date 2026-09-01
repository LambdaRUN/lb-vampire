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

    -- Blood Bag kullanım sunumu. Tamamlanmadan Blood uygulanmaz ve
    -- item tüketilmez. Bütün değerler sunucu sahibi tarafından değiştirilebilir.
    Use = {
        Duration = 6000,
        Label = 'Kan torbası kullanılıyor...',
        CanCancel = true,

        Animation = {
            Dictionary = 'mp_player_intdrink',
            Animation = 'loop_bottle',
            Flag = 49
        },

        Prop = {
            Enabled = true,
            Model = 'lb_vampire_bloodpack',
            Bone = 60309,
            Placement = {
                0.0080,
                0.0010,
                0.0160,
                3.5690,
                4.6611,
                -49.9065
            }
        },

        -- Kullanım boyunca elde/torba çevresinde hafif kan pulse'ları.
        -- FX doğrudan eldeki Blood Bag prop'unu takip eder; ped/karnından çıkmaz.
        BloodEffect = {
            Enabled = true,
            Asset = 'core',
            Effect = 'blood_mist',
            FollowProp = true,
            Interval = 650,
            Scale = 0.12,
            OffsetX = 0.0,
            OffsetY = 0.0,
            OffsetZ = 0.0
        },

        DisableControls = {
            disableMovement = false,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true
        },

        -- Client complete eventinin erken spoof edilmesini önlemek için
        -- server-side minimum elapsed kontrolünde tolerans.
        CompletionTolerance = 350
    },

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
        TickInterval = 250,

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

        -----------------------------------------------------
        -- Yalnız insan NPC'ler witness olabilir.
        -- Hayvanlar witness sayılmaz.
        -----------------------------------------------------

        HumanOnly = true,

        Radius = 25.0,

        MaximumWitnesses = 8,

        -----------------------------------------------------
        -- NORMAL WITNESS
        -----------------------------------------------------

        Panic = {
            Enabled = true,

            FleeDistance = 120.0,
            FleeDuration = 15000
        },

        -----------------------------------------------------
        -- CALLER
        --
        -- Dispatch roll başarılıysa en yakın uygun witness
        -- caller olarak seçilir.
        -----------------------------------------------------

        Caller = {
            Enabled = true,

            -------------------------------------------------
            -- Gerçek dispatch bu gecikmenin ardından düşer.
            -------------------------------------------------

            DispatchDelay = {
                Min = 4000,
                Max = 10000
            },

            -------------------------------------------------
            -- Önce olay yerinden biraz uzaklaşır.
            -------------------------------------------------

            MoveAwayDistance = 18.0,
            MoveAwayDuration = 2500,

            -------------------------------------------------
            -- Sonra telefon davranışı.
            -------------------------------------------------

            Phone = {
                Dictionary = 'cellphone@',
                Animation = 'cellphone_call_listen_base',

                Duration = 5000,
                Flag = 49
            },

            -------------------------------------------------
            -- Aramadan sonra uzaklaşır.
            -------------------------------------------------

            FleeAfterCall = true,

            FleeDistance = 120.0,
            FleeDuration = 15000
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

        -----------------------------------------------------
        -- WITNESS
        -----------------------------------------------------

        WitnessBonus = 25,

        AdditionalWitnessBonus = 5,
        MaxWitnessBonus = 40,

        -----------------------------------------------------
        -- KALABALIK BÖLGE
        -----------------------------------------------------

        BusyArea = {
            Enabled = true,

            Radius = 40.0,
            MinimumPeds = 4,

            Bonus = 15
        },

        -----------------------------------------------------
        -- GECE
        -----------------------------------------------------

        Night = {
            Enabled = true,

            StartHour = 22,
            EndHour = 5,

            Modifier = -15
        },

        -----------------------------------------------------
        -- TENHA
        -----------------------------------------------------

        Secluded = {
            Enabled = true,

            Radius = 45.0,

            MaximumPeds = 1,
            MaximumVehicles = 1,

            Modifier = -20
        },

        -----------------------------------------------------
        -- Witness yok ama dispatch roll başarılıysa
        -- anonim / uzaktan ihbar gecikmesi.
        -----------------------------------------------------

        AnonymousDelay = {
            Min = 12000,
            Max = 25000
        },

        -----------------------------------------------------
        -- YARIDA BIRAKILAN BESLENME / SALDIRI
        -----------------------------------------------------

        PartialIncident = {
            Enabled = true,

            -- 0-2 saniyelik kazara temaslarda dispatch üretmemek için.
            MinimumBloodLoss = 7,

            -- Aynı NPC üzerinde kısa aralıklarla beslenme spam'i yapılırsa
            -- kayıplar bu pencere içinde birlikte değerlendirilir.
            MemoryWindow = 60 * 1000,

            Severity = {
                Light = {
                    MinLoss = 7,
                    BaseChance = 10
                },

                Medium = {
                    MinLoss = 25,
                    BaseChance = 20
                },

                Heavy = {
                    MinLoss = 55,
                    BaseChance = 35
                }
            },

            -- Canlı bırakılan saldırıda ölüm olayından biraz daha düşük
            -- çevre çarpanları kullanılır.
            Modifiers = {
                WitnessBonus = 20,
                AdditionalWitnessBonus = 5,
                MaxWitnessBonus = 35,

                BusyBonus = 10,
                NightModifier = -10,
                SecludedModifier = -15
            },

            -- Hayatta kalan kurban dispatch roll başarılıysa
            -- kendi başına ihbarcı olma şansına sahiptir.
            VictimCaller = {
                Enabled = true,

                HealthyThreshold = 60,
                HealthyChance = 80,

                WeakThreshold = 30,
                WeakChance = 50,

                CriticalChance = 20
            }
        }
    },

    Debug = {
        Enabled = true,

        MaxDistance = 5.0,

        Target = {
            Enabled = true,

            Label = 'NPC Kanını Sıfırla [DEBUG]',
            Icon = 'fas fa-droplet',

            Distance = 2.5
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
        -- 200ms = saniyede 5 küçük güncelleme. Transfer delta-time bazlı
        -- olduğu için toplam NPC feeding süresi yine 30 saniyedir; sadece
        -- beslenme barı basamak basamak değil akıcı görünür.
        TickInterval = 200,

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



---------------------------------------------------------
-- 5C - BLOOD SIGIL ABILITY MENU
---------------------------------------------------------

Config.AbilityMenu = {
    Enabled = true,

    -- FiveM RegisterKeyMapping varsayılanı. Oyuncu bunu
    -- ESC > Settings > Key Bindings > FiveM içinden değiştirebilir.
    DefaultKey = 'LMENU',
    KeyDescription = 'LB Vampire - Ability Menu',

    -- Crysis tarzı: tuşa basılı tut -> mouse yönü -> tuşu bırak.
    Input = {
        Deadzone = 70,
        CursorRadius = 260,
        MinimumSlots = 6,
        MaxSlots = 10
    },

    -- UI yalnız sunum metadata'sını bilir. Gerçek kullanım ve status
    -- ability modülünün client/server provider'ından gelir.
    Abilities = {
        beast_call = {
            Enabled = true,
            Order = 1,
            Label = 'Beast Call',
            Description = 'Kanının çağrısıyla vahşi bir avı kendine çek.',
            Icon = 'beast'
        }
    }
}

---------------------------------------------------------
-- 5B - BEAST CALL
---------------------------------------------------------

Config.BeastCall = {
    Enabled = true,

    -----------------------------------------------------
    -- WILDERNESS SAFE ZONES
    --
    -- Bunlar PD / hastane safezone'u değildir.
    -- Beast Call avlanması için düşük dispatch riskli
    -- ormanlık/doğal alanlardır.
    --
    -- Hayvandan ilk başarılı kan transferinin gerçekleştiği
    -- konum bu alanlardan birindeyse SafezoneChance,
    -- değilse OutsideChance kullanılır.
    -----------------------------------------------------

    SafeZones = {
        {
            Name = 'Paleto Forest',
            Coords = { x = -720.0, y = 5480.0, z = 45.0 },
            Radius = 900.0
        },
        {
            Name = 'Mount Chiliad',
            Coords = { x = 390.0, y = 5570.0, z = 760.0 },
            Radius = 850.0
        },
        {
            Name = 'Raton Canyon',
            Coords = { x = -1510.0, y = 4420.0, z = 35.0 },
            Radius = 850.0
        },
        {
            Name = 'Tongva Hills',
            Coords = { x = -1760.0, y = 1470.0, z = 105.0 },
            Radius = 850.0
        }
    },

    -----------------------------------------------------
    -- ABILITY
    -----------------------------------------------------

    BloodCost = 10,

    Cooldown = {
        Min = 1 * 60,--10 * 60,
        Max = 2 * 60, --15 * 60
    },

    -- Gerçek ability UI daha sonra bu export'u çağıracak.
    -- Şimdilik yalnız Config.Debug=true iken /vambeastcall
    -- ile test edilir.
    DebugCommand = 'vambeastcall',

    -----------------------------------------------------
    -- PREY SPAWN
    -----------------------------------------------------

    Spawn = {
        MinDistance = 90.0,
        MaxDistance = 160.0,
        Attempts = 14,
        GroundProbeHeight = 60.0,
        CollisionWait = 120,
        ModelTimeout = 5000,

        -- Tracking çok uzun süre açık kalıp entity bırakmasın.
        SessionTimeout = 1 * 60 * 1000, --5 * 60 * 1000,
        MaximumTrackingDistance = 450.0,

        WanderRadius = 28.0
    },

    -----------------------------------------------------
    -- WEIGHTED ANIMALS
    -- Weight yalnız seçilme ihtimalidir.
    -- Blood ise hayvanın kan rezervidir.
    -----------------------------------------------------

    Animals = {
        deer = {
            Model = 'a_c_deer',
            Label = 'Geyik',
            Weight = 90,
            Blood = 50,
            AnimationProfile = 'deer'
        },

        boar = {
            Model = 'a_c_boar',
            Label = 'Yaban Domuzu',
            Weight = 25,
            Blood = 40,
            AnimationProfile = 'boar'
        },

        coyote = {
            Model = 'a_c_coyote',
            Label = 'Çakal',
            Weight = 20,
            Blood = 25,
            AnimationProfile = 'coyote'
        },

        rabbit = {
            Model = 'a_c_rabbit_01',
            Label = 'Tavşan',
            Weight = 15,
            Blood = 15,
            AnimationProfile = 'rabbit'
        }
    },

    -----------------------------------------------------
    -- SCENT TRACKING
    -- Blip / metre göstermez. Koku şiddeti + yön pulse'u.
    -----------------------------------------------------

    Tracking = {
        Enabled = true,

        FoundDistance = 20.0,

        PulseDuration = 450,

        Strengths = {
            Faint = {
                MinDistance = 120.0,
                Interval = 2200,
                Label = 'Zayıf Koku'
            },
            Detected = {
                MinDistance = 65.0,
                Interval = 1550,
                Label = 'Koku Algılandı'
            },
            Strong = {
                MinDistance = 28.0,
                Interval = 950,
                Label = 'Güçlü Koku'
            },
            Nearby = {
                MinDistance = 0.0,
                Interval = 600,
                Label = 'Av Yakında!'
            }
        }
    },

    -----------------------------------------------------
    -- ANIMAL FEEDING
    -----------------------------------------------------

    Feeding = {
        Interaction = {
            Distance = 2.5,
            Label = 'Beslen',
            Icon = 'fas fa-tint'
        },

        Transfer = {
            -- Server authoritative kalır ama 200ms update ile UI'daki
            -- 500ms'lik basamak hissi ortadan kalkar. Mevcut 250ms
            -- linear NUI transition ile bar kesintisiz akar.
            TickInterval = 200,

            -- 5 Blood/sn: Geyik ~10sn, Domuz ~8sn,
            -- Çakal ~5sn, Tavşan ~3sn tam boşalır.
            -- Böylece Beast dispatch başarılı olsa bile av döngüsü
            -- gereksiz yere 20-25 saniyeye uzamaz.
            RatePerSecond = 5.0,
            GainRatio = 1.0
        },

        Interrupts = {
            Enabled = true,
            ClientCheckInterval = 100,
            MaxDistance = 3.5,
            CancelOnDeath = true,
            CancelInVehicle = true,
            CancelOnDamage = true,
            CancelOnRagdoll = true,
            TeleportDistance = 5.0
        },

        StatusUI = {
            Enabled = true,
            Thresholds = {
                Low = 70,
                Critical = 40,
                Severe = 20
            }
        },

        -------------------------------------------------
        -- Yalnız VAMPİR animasyon oynar.
        -- Hayvan hiçbir insan animasyonuna sokulmaz.
        --
        -- Eski root/body offset yaklaşımı özellikle geyikte
        -- karakteri gövdenin arkasına bırakıyordu. Artık her tür
        -- hayvanın HEAD bone'u referans alınır; yalnız X/Y o bone'a
        -- göre hesaplanır, oyuncunun Z konumu zeminden alınır.
        --
        -- SideOffset: hayvanın sağ/sol tarafı
        -- ForwardOffset: baştan boyuna doğru geri/ileri
        -- RotZ: FaceAnchor ile bulunan yönün üstüne eklenen sağ/sol dönüş.
        -------------------------------------------------

        AnimationProfiles = {
            deer = {
                Dictionary = 'amb@medic@standing@kneel@base',--'genesismods_kissme@kissmale9',
                Animation = 'base',--'kissmale9',
                Flag = 1,
                AnchorBone = 31086, -- SKEL_Head
                SideOffset = 0.49,
                ForwardOffset = -0.30,
                GroundOffsetZ = 0.0,
                RotZ = 0.0,
                BloodEffect = {
                    FlowScale = 0.30,
                    AccentScale = 0.22,
                    GroundScale = 1.00
                },
                FaceAnchor = true
            },

            boar = {
                Dictionary = 'amb@medic@standing@kneel@base',
                Animation = 'base',
                Flag = 1,
                AnchorBone = 31086,
                SideOffset = 0.48,
                ForwardOffset = -0.30,
                GroundOffsetZ = 0.0,
                RotZ = 0.0,
                BloodEffect = {
                    FlowScale = 0.26,
                    AccentScale = 0.20,
                    GroundScale = 0.90
                },
                FaceAnchor = true
            },

            coyote = {
                Dictionary = 'amb@medic@standing@kneel@base',
                Animation = 'base',
                Flag = 1,
                AnchorBone = 31086,
                SideOffset = 0.40,
                ForwardOffset = -0.24,
                GroundOffsetZ = 0.0,
                RotZ = 0.0,
                BloodEffect = {
                    FlowScale = 0.19,
                    AccentScale = 0.15,
                    GroundScale = 0.68
                },
                FaceAnchor = true
            },

            rabbit = {
                Dictionary = 'amb@world_human_gardener_plant@male@base',
                Animation = 'base',
                Flag = 1,
                AnchorBone = 31086,
                SideOffset = 0.34,
                ForwardOffset = -0.12,
                GroundOffsetZ = 0.0,
                RotZ = 0.0,
                BloodEffect = {
                    FlowScale = 0.10,
                    AccentScale = 0.08,
                    GroundScale = 0.38
                },
                FaceAnchor = true
            }
        },

        -------------------------------------------------
        -- ANIMAL BLOOD FX
        -- Her hayvanda aynı sistem çalışır; profil içindeki
        -- BloodEffect değerleri sadece yoğunluğu ölçekler.
        -------------------------------------------------

        BloodEffects = {
            Enabled = true,

            Asset = 'core',
            LoadTimeout = 3000,

            -- blood_fall tek-shot bir PTFX gibi davrandığı için gerçek akış
            -- hissini kısa aralıklarla tekrar eden bone pulse'ları oluşturur.
            Flow = {
                Enabled = true,
                Effect = 'blood_fall',
                Interval = 280,

                OffsetX = 0.0,
                OffsetY = 0.0,
                OffsetZ = 0.0,
            },

            -- Beslenme sürerken ara sıra kısa vurgu efekti.
            Accent = {
                Enabled = true,

                Effects = {
                    'blood_throat',
                    'blood_mist'
                },

                MinInterval = 850,
                MaxInterval = 1550,

                OffsetX = 0.0,
                OffsetY = 0.0,
                OffsetZ = 0.0,
            },

            -- Boynun altındaki zeminde sınırlı sayıda kan havuzu.
            Ground = {
                Enabled = true,

                -- GTA V blood solid pool decal.
                DecalType = 9001,

                InitialDelay = 650,
                Interval = 1400,
                MaxDecals = 3,

                Width = 0.62,
                Height = 0.62,
                Spread = 0.16,
                GroundOffsetZ = 0.018,

                Red = 0.32,
                Green = 0.0,
                Blue = 0.0,
                Opacity = 0.88,

                -- Saniye cinsinden yerde kalma süresi.
                Timeout = 45.0
            }
        }
    },

    -----------------------------------------------------
    -- DISPATCH
    -- İlk başarılı animal-blood tick'inde sadece 1 kez roll.
    -----------------------------------------------------

    Dispatch = {
        Enabled = true,

        SafezoneChance = 15,
        OutsideChance = 55,

        Delay = {
            Min = 5000,
            Max = 12000
        }
    },

    -----------------------------------------------------
    -- CLEANUP
    -----------------------------------------------------

    Cleanup = {
        FleeDistance = 180.0,

        -- Yarıda bırakılan hayvan hemen kaçar; oyuncu kaçışı
        -- görür, ardından entity temizlenir.
        ReleaseDespawnDelay = 12000,

        DrainedDespawnDelay = 15000,
        LostDespawnDelay = 1500
    }
}

Config.Dispatch = {
    Enabled = true,

    Provider = 'auto',

    Auto = {
        PreferPS = true
    },

    Alerts = {
        NPCDeath = {
            Title = 'Şüpheli Saldırı',

            Description =
                'Şüpheli Saldırı İhbarı.'
        },

        BeastCall = {
            Title = 'Vahşi Hayvan İhbarı',

            Description =
                'Ölü Hayvan İhbarı.'
        },

        Suspicious = {
            Title = 'Şüpheli Aktivite',

            Description =
                'Bölgede şüpheli bir olay bildirildi.'
        }
    },

    PS = {
        Resource = 'ps-dispatch',

        Profiles = {
            NPCDeath = {
                CodeName = 'civdead',
                Code = '10-66',
                Icon = 'fas fa-person-falling',
                Priority = 2,

                Jobs = {
                    'leo',
                    'police'
                }
            },

            BeastCall = {
                CodeName = 'hunting',
                Code = '10-54',
                Icon = 'fas fa-paw',
                Priority = 2,

                Jobs = {
                    'leo',
                    'police'
                }
            },

            Suspicious = {
                CodeName = 'civdead',
                Code = '10-66',
                Icon = 'fas fa-triangle-exclamation',
                Priority = 2,

                Jobs = {
                    'leo',
                    'police'
                }
            }
        }
    },

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

---------------------------------------------------------
-- 5D - VAMPIRE DAMAGE / TORPOR FOUNDATION
---------------------------------------------------------

Config.VampireDamage = {
    Enabled = true,

    -- GTA/FiveM hasarı yalnız vampirlerde bu çarpanlardan geçirilir.
    -- Deadblood, NormalAmmoMultiplier ile çarpılmaz; kendi profilidir.
    Types = {
        BULLET = { NormalMultiplier = 0.25 },
        MELEE = { Multiplier = 0.50 },

        -- Normal yüksekten düşme hasarı çarpanı.
        -- 1.00 = GTA/FiveM taban hasarı, 0.50 = yarısı, 1.50 = %50 fazla.
        -- Super Jump gibi ability inişleri bu çarpana gelmeden exemption katmanında 0 hasar alır.
        FALL = { Multiplier = 1.00 },

        VEHICLE = { Multiplier = 1.00 },
        EXPLOSION = { Multiplier = 1.25 },
        FIRE = { Multiplier = 1.00 },
        DROWNING = { Multiplier = 1.00 },
        SUNLIGHT = { Multiplier = 1.00 },
        UNKNOWN = { Multiplier = 1.00 }
    },

    AmmoVariants = {
        deadblood = {
            Label = 'Ölü Adamın Kanından Mermi',
            VampireMultiplier = 3.00
        }
    },

    -- PVP weapon hasarı server-side CancelEvent ile reddedilmez. FiveM'de
    -- shooter client hit'i önceden tahmin ettiği için cancellation shooter-only
    -- death/ragdoll desync oluşturabilir. Native hit victim client'ta gözlenir,
    -- snapshot anında restore edilir ve tek sonuç LB router'dan uygulanır.
    VictimSideRouting = true,

    -- Tek bir bozuk/yanlış event yüzünden devasa değer uygulanmasını engeller.
    MaxObservedDamagePerEvent = 250.0,

    -- Server route reddeder/yanıt vermezse native hasar bu sürenin sonunda
    -- geri uygulanır; oyuncu restore edilmiş HP ile dokunulmaz kalmaz.
    ClientFallbackTimeout = 2000,

    -- GTA player ped health tabanı. Effective HP = EntityHealth - BaseHealth.
    BaseHealth = 100,

    Debug = false
}

Config.Torpor = {
    Enabled = true,

    -- Hem aktif Torpor hem de EMS revive sonrası Kısmi Torpor bu Blood
    -- seviyesine ulaştığı anda kırılır.
    RecoveryBlood = 15,

    Active = {
        -- ReferenceHealth kadar efektif HP'nin Torpor içinde tamamen
        -- tükenmesinin hedef süresi. Ör: 100 HP / 300 sn = 0.333 HP/sn.
        FullHealthDuration = 5 * 60,
        ReferenceHealth = 100,
        MovementClipset = 'move_m@injured'
    },

    Partial = {
        -- EMS revive sonrası Blood hâlâ RecoveryBlood altındaysa kullanılır.
        -- HP drain yoktur; yalnız Torpor kısıtlamaları devam eder.
        MovementClipset = 'move_m@injured'
    },

    KinCall = {
        Enabled = true,
        Key = 74, -- H
        MaxCallsPerCollapse = 1,
        AreaRadius = 90.0,
        OffsetMin = 35.0,
        OffsetMax = 65.0,
        BlipDuration = 75 * 1000,
        BlipColour = 1,
        BlipAlpha = 105,
        Label = 'Zayıf Kan Bağı'
    },

    ScreenEffect = {
        Enabled = true,
        Timecycle = 'NG_filmic04',
        ActiveStrength = 0.18,
        PartialStrength = 0.12
    }
}

Config.DeadBloodAmmo = {
    Enabled = true,
    ItemName = 'ammo_deadblood',
    Label = 'Ölü Adamın Kanından Mermi',
    Description = 'Vampir dokusuna karşı hazırlanmış özel mühimmat.',
    Weight = 250,
    Image = 'pistol_ammo.png',
    RoundsPerItem = 12,
    MaxRounds = 60,

    -- Universal özel ammo: mevcut seçili firearm bu gruplardan birindeyse yüklenebilir.
    AllowedGroups = {
        PISTOL = true,
        SMG = true,
        RIFLE = true,
        MG = true,
        SHOTGUN = true,
        SNIPER = true
    }
}
