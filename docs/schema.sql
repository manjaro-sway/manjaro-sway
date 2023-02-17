DROP TABLE IF EXISTS visitor_statistics;
CREATE TABLE visitor_statistics (
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    count INTEGER NOT NULL,
    PRIMARY KEY (`timestamp`)
);
