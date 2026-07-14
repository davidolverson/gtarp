-- 0046_market.sql — palm6_market (Palm6 Commodity Exchange)
-- Server-authoritative supply/demand market for palm6_grind raw goods.
-- Prefixed `palm6_` per the table-naming convention (post palm6_housing incident).

-- Live per-commodity price state. price + last_ts are the ONLY persisted market
-- state; the current price is recomputed from them + wall-clock on every read,
-- so the market is restart- and relog-safe with no ticks.
CREATE TABLE IF NOT EXISTS palm6_market_state (
    commodity   VARCHAR(64)  NOT NULL PRIMARY KEY,
    price       DOUBLE       NOT NULL,
    last_ts     BIGINT       NOT NULL
);

-- Sale ledger (audit + future analytics). Best-effort: a failed insert never
-- blocks or undoes a completed sale.
CREATE TABLE IF NOT EXISTS palm6_market_trades (
    id          INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid   VARCHAR(64)  NOT NULL,
    commodity   VARCHAR(64)  NOT NULL,
    qty         INT          NOT NULL,
    total       INT          NOT NULL,
    ts          BIGINT       NOT NULL,
    INDEX idx_palm6_market_trades_cid (citizenid),
    INDEX idx_palm6_market_trades_commodity (commodity)
);
