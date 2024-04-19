DROP TABLE IF EXISTS downloads;
CREATE TABLE downloads (
    timestamp DATETIME DEFAULT CURRENT_DATE,
    count INTEGER NOT NULL,
    PRIMARY KEY (`timestamp`)
);
INSERT INTO downloads (count) VALUES (0);