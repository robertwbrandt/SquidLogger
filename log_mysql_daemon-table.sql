--
-- setup statements
--
-- CREATE DATABASE squid_log;
-- GRANT INSERT,SELECT ON squid_log.* TO 'squid'@'localhost' IDENTIFIED BY 'squid';

--
-- DDL statements
--
-- USE squid_log;

--
-- This table is based on squid's default 'squid' logformat, with minor modifications
-- (the two slashes are removed)
-- original:
-- logformat squid  %ts.%03tu %6tr %>a %Ss/%03Hs %<st %rm %ru %un %Sh/%<A %mt
-- modified:
-- logformat squid  %ts.%03tu %6tr %>a %Ss %03Hs %<st %rm %ru %un %Sh %<A %mt
-- changes:                               ^                          ^
-- 
CREATE TABLE access_log (
    id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    time_since_epoch     DECIMAL(15,3),
    date_day             DATE,                  -- set by trigger
    date_time            TIME,                  -- set by trigger
    response_time        INTEGER,
    client_src_ip_addr   CHAR(15),
    squid_request_status VARCHAR(50),
    http_status_code     VARCHAR(10),
    reply_size           INTEGER,
    request_method       VARCHAR(20),
    request_url          VARCHAR(200),
    username             VARCHAR(40),
    squid_hier_status    VARCHAR(20),
    server_ip_addr       CHAR(15),
    mime_type            VARCHAR(50)
) ENGINE=MYISAM;

-- trigger that extracts the date value from the time_since_epoch column
-- and stores it in the date_day and date_time columns
-- this allows fast calculation of per-day aggregate values
DELIMITER //
CREATE TRIGGER extract_date_bi BEFORE INSERT ON access_log FOR EACH ROW
BEGIN
    SET NEW.date_day  = DATE(FROM_UNIXTIME(NEW.time_since_epoch));
    SET NEW.date_time = TIME(FROM_UNIXTIME(NEW.time_since_epoch));
END; //

