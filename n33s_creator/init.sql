CREATE TABLE IF NOT EXISTS `characters` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `slot` TINYINT UNSIGNED NOT NULL,
    `firstname` VARCHAR(32) NOT NULL,
    `lastname` VARCHAR(32) NOT NULL,
    `nationality` VARCHAR(48) NOT NULL DEFAULT 'Nieznane',
    `dateofbirth` VARCHAR(10) NOT NULL,
    `height` SMALLINT UNSIGNED NOT NULL,
    `gender` ENUM('male', 'female') NOT NULL,
    `skin` LONGTEXT NOT NULL,
    `coords` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_characters_identifier_slot` (`identifier`, `slot`),
    KEY `idx_characters_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
