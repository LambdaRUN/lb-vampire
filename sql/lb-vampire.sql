CREATE TABLE IF NOT EXISTS `vampire_characters` (
    `citizenid` VARCHAR(50) NOT NULL,
    `is_vampire` TINYINT(1) NOT NULL DEFAULT 1,
    `sire_citizenid` VARCHAR(50) DEFAULT NULL,
    `blood` DECIMAL(6,2) NOT NULL DEFAULT 100.00,
    `can_embrace` TINYINT(1) NOT NULL DEFAULT 0,
    `embraced_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`citizenid`),
    KEY `idx_vampire_active` (`is_vampire`),
    KEY `idx_vampire_sire` (`sire_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE IF NOT EXISTS `vampire_human_state` (
    `citizenid` VARCHAR(50) NOT NULL,
    `blood_volume` DECIMAL(6,2) NOT NULL DEFAULT 100.00,
    `last_recovery_at` TIMESTAMP NULL DEFAULT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE vampire_characters
ADD COLUMN IF NOT EXISTS preferred_blood_type VARCHAR(3) NULL AFTER blood;