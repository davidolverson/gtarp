-- 0034_numbers.sql — tables for palm6_numbers. Apply after the qbx base schema.
-- palm6_-prefixed per the table-naming convention (see docs/GTA6-READINESS.md).

-- One row per placed bet. draw_seq groups bets into the draw they resolve in.
-- status: open (awaiting draw) -> won | lost. A won bet is paid out (in
-- black_money) only when the player collects, tracked by paid (0/1) — so a
-- winner who was offline at draw time still gets their winnings on collect.
CREATE TABLE IF NOT EXISTS `palm6_numbers_bets` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    number TINYINT UNSIGNED NOT NULL,
    stake INT UNSIGNED NOT NULL,
    draw_seq INT UNSIGNED NOT NULL,
    status ENUM('open', 'won', 'lost') NOT NULL DEFAULT 'open',
    payout INT UNSIGNED NOT NULL DEFAULT 0,
    paid TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_palm6_numbers_bets_draw (draw_seq, status),
    INDEX idx_palm6_numbers_bets_collect (citizenid, status, paid)
);

-- One row per resolved draw — the results history + volume ledger.
CREATE TABLE IF NOT EXISTS `palm6_numbers_draws` (
    draw_seq INT UNSIGNED NOT NULL PRIMARY KEY,
    winning_number TINYINT UNSIGNED NOT NULL,
    bets INT UNSIGNED NOT NULL DEFAULT 0,
    staked INT UNSIGNED NOT NULL DEFAULT 0,
    payout_total INT UNSIGNED NOT NULL DEFAULT 0,
    drawn_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
