-- 0031_gunrunning.sql — tables for palm6_gunrunning. Apply after the qbx base schema.
-- palm6_-prefixed per the table-naming convention (see docs/GTA6-READINESS.md
-- history — an unprefixed table silently collided with a recipe resource once).
CREATE TABLE IF NOT EXISTS `palm6_gunrunning_sales` (
    id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    serial           VARCHAR(32)  NOT NULL,
    buyer_citizenid  VARCHAR(64)  NOT NULL,
    weapon           VARCHAR(64)  NOT NULL,
    price            INT UNSIGNED NOT NULL,
    purchased_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_palm6_gunrunning_sales_serial (serial),
    INDEX idx_palm6_gunrunning_sales_citizenid (buyer_citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
