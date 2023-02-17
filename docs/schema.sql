DROP TABLE IF EXISTS visitor_statistics;
CREATE TABLE visitor_statistics (
    timestamp DATETIME DEFAULT CURRENT_DATE,
    count INTEGER NOT NULL,
    gain INTEGER NOT NULL,
    PRIMARY KEY (`timestamp`)
);
INSERT
    OR REPLACE INTO visitor_statistics (timestamp, count, gain)
VALUES ('2023-02-16', 69000, 500);
