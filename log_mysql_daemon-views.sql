--
-- Some sample views
--


--
-- Last 100 queries
--
CREATE OR REPLACE VIEW last_100_queries AS
SELECT
    *
FROM
    access_log
ORDER BY id DESC
LIMIT 100;



--
-- Cache clients by day
-- IP address version
--
CREATE OR REPLACE VIEW cache_clients_by_day_ipaddr AS
SELECT
    date_day,
    client_src_ip_addr
FROM
    access_log
GROUP BY 1,2
ORDER BY 1,2;


--
-- Cache clients by day
-- username version
--
CREATE OR REPLACE VIEW cache_clients_by_day_username AS
SELECT
    date_day,
    username
FROM
    access_log
GROUP BY 1,2
ORDER BY 1,2;


--
-- Number of requests per day
--
CREATE OR REPLACE VIEW requests_by_day AS
SELECT
    date_day,
    COUNT(*) AS total_requests
FROM
    access_log
GROUP BY 1
ORDER BY 1;


-- Index for cache_clients_by_day_ipaddr
CREATE INDEX date_day_client_src_ip_addr_idx ON access_log(date_day, client_src_ip_addr);

-- Index for cache_clients_by_day_ipaddr
CREATE INDEX date_day_username_idx ON access_log(date_day, username);


--
-- Total traffic by day
--
CREATE OR REPLACE VIEW total_traffic_by_day AS
SELECT
    date_day,
    SUM(reply_size) AS total_traffic
FROM
    access_log
GROUP BY 1
ORDER BY 1;

--
-- Index for total_traffic_by_day
--
CREATE INDEX date_day_reply_size_idx ON access_log(date_day, reply_size);



--
-- Number of HIT requests by day
--
CREATE OR REPLACE VIEW hit_requests_by_day AS
SELECT
    date_day,
    COUNT(*) AS hit_requests
FROM
    access_log
WHERE
    squid_request_status LIKE '%HIT'
GROUP BY 1
ORDER BY 1;


--
-- Number of MISS requests by day
--
CREATE OR REPLACE VIEW miss_requests_by_day AS
SELECT
    date_day,
    COUNT(*) AS miss_requests
FROM
    access_log
WHERE
    squid_request_status LIKE '%MISS'
GROUP BY 1
ORDER BY 1;


--
-- Index for the following views:
--   hit_requests_by_day
--   miss_requests_by_day
--
CREATE INDEX date_day_squid_request_status_idx ON access_log(date_day, squid_request_status);



--
-- hit traffic by day
--
CREATE OR REPLACE VIEW hit_traffic_by_day AS
SELECT
    date_day,
    SUM(reply_size) AS hit_traffic
FROM
    access_log
WHERE
    squid_request_status LIKE '%HIT'
GROUP BY 1
ORDER BY 1;


--
-- Index for hit_traffic_by_day
--
CREATE INDEX date_day_reply_size_squid_request_status_idx ON access_log(date_day, reply_size, squid_request_status);



--
-- Request and byte hit ratios by day
--

-- the following view doeas the job...
CREATE OR REPLACE VIEW _hit_ratios_by_day AS
SELECT
    a.date_day,
    (
        SELECT
            b.hit_requests
        FROM
            hit_requests_by_day b
        WHERE
            b.date_day = a.date_day
    )
    /
    (
        SELECT
            c.total_requests
        FROM
            requests_by_day c
        WHERE
            c.date_day = a.date_day
    )
    * 100 AS request_hit_ratio,

    (
        SELECT
            d.hit_traffic
        FROM
            hit_traffic_by_day d
        WHERE
            d.date_day = a.date_day
    )
    /
    (
        SELECT
            e.total_traffic
        FROM
            total_traffic_by_day e
        WHERE
            e.date_day = a.date_day
    )
    * 100 AS byte_hit_ratio
FROM
    access_log a
GROUP BY 1
ORDER BY 1;


-- ...while this one prevents NULLs from
-- popping up for days with no HIT request
CREATE OR REPLACE VIEW hit_ratios_by_day AS
SELECT
    date_day,
    IFNULL(request_hit_ratio,0) AS request_hit_ratio,
    IFNULL(byte_hit_ratio,0)    AS byte_hit_ratio
FROM
    _hit_ratios_by_day;




--
-- Traffic by day by client
-- IP address version
--
CREATE OR REPLACE VIEW total_traffic_by_day_by_client_ipaddr AS
SELECT
    date_day,
    client_src_ip_addr,
    SUM(reply_size) AS total_traffic
FROM
    access_log
GROUP BY 1,2
ORDER BY 1,2;

--
-- Index for total_traffic_by_day_by_client_ipaddr
--
CREATE INDEX date_day_client_src_ip_addr_reply_size_idx ON access_log(date_day, client_src_ip_addr, reply_size);


--
-- Traffic by day by client
-- username version
--
CREATE OR REPLACE VIEW total_traffic_by_day_by_client_username AS
SELECT
    date_day,
    username,
    SUM(reply_size) AS total_traffic
FROM
    access_log
GROUP BY 1,2
ORDER BY 1,2;

--
-- Index for total_traffic_by_day_by_client_username
--
CREATE INDEX date_day_username_reply_size_idx ON access_log(date_day, username, reply_size);


--
-- hit traffic by day by client
-- IP address version
--
CREATE OR REPLACE VIEW hit_traffic_by_day_by_client_ipaddr AS
SELECT
    date_day,
    client_src_ip_addr,
    SUM(reply_size) AS hit_traffic
FROM
    access_log
WHERE
    squid_request_status LIKE '%HIT'
GROUP BY 1,2
ORDER BY 1,2;


--
-- Number of HIT requests by day by client
-- IP address version
--
CREATE OR REPLACE VIEW hit_requests_by_day_by_client_ipaddr AS
SELECT
    date_day,
    client_src_ip_addr,
    COUNT(*) AS hit_requests
FROM
    access_log
WHERE
    squid_request_status LIKE '%HIT'
GROUP BY 1,2
ORDER BY 1,2;


--
-- Index for:
--   hit_traffic_by_day_by_client_ipaddr
--   hit_requests_by_day_by_client_ipaddr
CREATE INDEX date_day_client_src_ip_addr_reply_size_squid_request_status_idx ON access_log(date_day, client_src_ip_addr, reply_size, squid_request_status);


--
-- hit traffic by day by client
-- username version
--
CREATE OR REPLACE VIEW hit_traffic_by_day_by_client_username AS
SELECT
    date_day,
    username,
    SUM(reply_size) AS hit_traffic
FROM
    access_log
WHERE
    squid_request_status LIKE '%HIT'
GROUP BY 1,2
ORDER BY 1,2;


--
-- Number of HIT requests by day by client
-- username version
--
CREATE OR REPLACE VIEW hit_requests_by_day_by_client_username AS
SELECT
    date_day,
    username,
    COUNT(*) AS hit_requests
FROM
    access_log
WHERE
    squid_request_status LIKE '%HIT'
GROUP BY 1,2
ORDER BY 1,2;


--
-- Index for:
--   hit_traffic_by_day_by_client_username
--   hit_requests_by_day_by_client_username
CREATE INDEX date_day_username_reply_size_squid_request_status_idx ON access_log(date_day, username, reply_size, squid_request_status);


--
-- Request and byte hit ratios by day by client
-- IP address version
--

-- the following view doeas the job...
CREATE OR REPLACE VIEW _hit_ratios_by_day_by_client_ipaddr AS
SELECT
    a.date_day,
    a.client_src_ip_addr,
    (
        SELECT
            b.hit_requests
        FROM
            hit_requests_by_day_by_client_ipaddr b
        WHERE
            b.date_day = a.date_day
        AND b.client_src_ip_addr = a.client_src_ip_addr
    )
    /
    (
        SELECT
            c.total_requests
        FROM
            requests_by_day c
        WHERE
            c.date_day = a.date_day
    )
    * 100 AS request_hit_ratio,

    (
        SELECT
            d.hit_traffic
        FROM
            hit_traffic_by_day_by_client_ipaddr d
        WHERE
            d.date_day = a.date_day
        AND d.client_src_ip_addr = a.client_src_ip_addr
    )
    /
    (
        SELECT
            e.total_traffic
        FROM
            total_traffic_by_day e
        WHERE
            e.date_day = a.date_day
    )
    * 100 AS byte_hit_ratio
FROM
    access_log a
GROUP BY 1
ORDER BY 1;


-- ...while this one prevents NULLs from
-- popping up for days with no HIT requests
CREATE OR REPLACE VIEW hit_ratios_by_day_by_client_ipaddr AS
SELECT
    date_day,
    client_src_ip_addr,
    IFNULL(request_hit_ratio,0) AS request_hit_ratio,
    IFNULL(byte_hit_ratio,0)    AS byte_hit_ratio
FROM
    _hit_ratios_by_day_by_client_ipaddr;



--
-- Request and byte hit ratios by day by client
-- username version
--

-- the following view doeas the job...
CREATE OR REPLACE VIEW _hit_ratios_by_day_by_client_username AS
SELECT
    a.date_day,
    a.username,
    (
        SELECT
            b.hit_requests
        FROM
            hit_requests_by_day_by_client_username b
        WHERE
            b.date_day = a.date_day
        AND b.username = a.username
    )
    /
    (
        SELECT
            c.total_requests
        FROM
            requests_by_day c
        WHERE
            c.date_day = a.date_day
    )
    * 100 AS request_hit_ratio,

    (
        SELECT
            d.hit_traffic
        FROM
            hit_traffic_by_day_by_client_username d
        WHERE
            d.date_day = a.date_day
        AND d.username = a.username
    )
    /
    (
        SELECT
            e.total_traffic
        FROM
            total_traffic_by_day e
        WHERE
            e.date_day = a.date_day
    )
    * 100 AS byte_hit_ratio
FROM
    access_log a
GROUP BY 1
ORDER BY 1;


-- ...while this one prevents NULLs from
-- popping up for days with no HIT requests
CREATE OR REPLACE VIEW hit_ratios_by_day_by_client_username AS
SELECT
    date_day,
    username,
    IFNULL(request_hit_ratio,0) AS request_hit_ratio,
    IFNULL(byte_hit_ratio,0)    AS byte_hit_ratio
FROM
    _hit_ratios_by_day_by_client_username;



--
-- total traffic for request with status TCP_DENIED
--
CREATE OR REPLACE VIEW denied_traffic_by_day AS
SELECT
    date_day,
    SUM(reply_size) AS denied_traffic
FROM
    access_log
WHERE
    squid_request_status = 'TCP_DENIED'
GROUP BY 1
ORDER BY 1;


--
-- total traffic by day for requests of type *_HIT and DENIED
--
CREATE OR REPLACE VIEW denied_or_hit_traffic_by_day AS
SELECT
    date_day,
    SUM(reply_size) as saved_traffic_bytes
FROM
    access_log
WHERE
    squid_request_status = 'TCP_DENIED'
    OR squid_request_status LIKE '%HIT'
GROUP BY 1 ORDER BY 1;


--
-- 100 most requested domain
--
CREATE OR REPLACE VIEW most_requested_domains AS
SELECT
    request_url,
    COUNT(*) AS num_requests
FROM
    access_log
GROUP BY 1
ORDER BY 2 DESC
LIMIT 100;

--
-- Index for most_requested_domains view
--
CREATE INDEX request_url_idx ON access_log(request_url);


--
-- Domains generating the highest traffic
--
CREATE OR REPLACE VIEW highest_traffic_domains AS
SELECT
    request_url,
    SUM(reply_size) AS traffic_bytes,
    SUM(reply_size) / 1024 AS traffic_kb,
    SUM(reply_size) / (1024 * 1024) AS traffic_mb
FROM
    access_log
GROUP BY 1
ORDER BY 2 DESC
LIMIT 100;

--
-- Index for highest traffic domains view
--
CREATE INDEX request_url_reply_size_idx ON access_log(request_url, reply_size);


--
-- For every day which has traffic,
-- show the number of requests for each site
-- that has more than 100 requests.
-- Adjust '100' in HAVING clause to match
-- traffic in your squid deployment.
--
CREATE OR REPLACE VIEW most_requested_domains_by_day AS
SELECT
    date_day,
    request_url,
    COUNT(*) as num_requests
FROM
    access_log
GROUP BY 1, 2
HAVING COUNT(*) > 100
ORDER BY 1, 3 DESC;


--
-- For every day which has traffic,
-- show the number of bytes requested from each site
-- from which more that 5000000 bytes have been requested
-- Adjust '5000000' in HAVING clause to match
-- traffic in your squid deployment.
--
CREATE OR REPLACE VIEW highest_traffic_domains_by_day AS
SELECT
    date_day,
    request_url,
    SUM(reply_size) AS traffic_bytes,
    SUM(reply_size) / 1024 AS traffic_kb,
    SUM(reply_size) / (1024 * 1024) AS traffic_mb
FROM
    access_log
GROUP BY 1, 2
HAVING SUM(reply_size) > 5000000
ORDER BY 1, 3 DESC;


--
-- Saved traffic percent
--
CREATE OR REPLACE VIEW traffic_savings_by_day AS
SELECT
    a.date_day,
    a.total_traffic,
    b.saved_traffic_bytes,
    b.saved_traffic_bytes / a.total_traffic * 100 as saved_bytes_percent
FROM
    total_traffic_by_day a
JOIN denied_or_hit_traffic_by_day b ON a.date_day = b.date_day;

