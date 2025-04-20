CREATE TABLE IF NOT EXISTS `windpower_stations` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `owner` varchar(50) DEFAULT NULL,
    `location` varchar(255) NOT NULL,
    `level` int(11) DEFAULT 1,
    `production` int(11) DEFAULT 100,
    `status` VARCHAR(50) DEFAULT 'operational',
    `stored_money` INT DEFAULT 0,
    PRIMARY KEY (`id`)
);

ALTER TABLE windpower_stations ADD COLUMN health INT DEFAULT 100;
