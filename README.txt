     * NAME
     * SYNOPSIS
     * DESCRIPTION
     * CONFIGURATION
          * Squid configuration
               * logformat directive
               * access_log directive
               * logfile_daemon directive
          * Database configuration
               * Database
               * User
               * Tables and views
     * VERSION INFORMATION
     * DATA EXTRACTION
          * Speed issues
     * BUGS & TODO
          * Squid version
          * Table cleanup
          * Testing
     * DEPENDENCIES
     * CHANGELOG
     * AUTHOR
     * COPYRIGHT AND LICENSE

     ------------------------------------------------------------------------------------

                                             NAME

   log_mysql_daemon.pl - Write squid access log into a mysql database

     ------------------------------------------------------------------------------------

                                           SYNOPSIS

   mysql -u root -p squid_log < log_mysql_daemon.sql

   cp log_mysql_daemon.pl /path/to/squid/libexec/

   then, in squid.conf:

   logformat squid_mysql  %ts.%03tu %6tr %>a %Ss %03Hs %<st %rm %ru %un %Sh %<A %mt

   access_log daemon:/mysql_host/database/table/username/password squid_mysql

   logfile_daemon /path/to/squid/libexec/log_mysql_daemon.pl

     ------------------------------------------------------------------------------------

                                         DESCRIPTION

   This script exploits the new logfile daemon support available in squid 2.7 to store
   access log entries in a MySQL database.

     ------------------------------------------------------------------------------------

                                        CONFIGURATION

Squid configuration

  logformat directive

   This script expects the following log format (it's the default 'squid' log format
   without the two '/' characters):

   logformat squid_mysql  %ts.%03tu %6tr %>a %Ss %03Hs %<st %rm %ru %un %Sh %<A %mt

  access_log directive

   The path to the access log file is used to provide the database connection parameters.

   access_log daemon:/mysql_host/database/table/username/password squid_mysql

   The 'daemon' prefix is mandatory and tells squid that the logfile_daemon is to be used
   instead of the normal file logging.

   The last parameter, 'squid_mysql' in the example, tells squid which log format to use
   when writing lines to the log daemon.

   mysql_host

           Host where the mysql server is running. If left empty, 'localhost' is assumed.

   database

           Name of the database to connect to. If left empty, 'squid_log' is assumed.

   table

           Name of the database table where log lines are stored. If left empty,
           'access_log' is assumed.

   username

           Username to use when connecting to the database. If left empty, 'squid' is
           assumed.

   password

           Password to use when connecting to the database. If left empty, no password is
           used.

   To leave all fields to their default values, you can use a single slash:

   access_log daemon:/ squid_mysql

   To specify only the database password, which by default is empty, you must leave
   unspecified all the other parameters by using null strings:

   access_log daemon://///password squid_mysql

  logfile_daemon directive

   This is the current way of telling squid where the logfile daemon resides.

   logfile_daemon /path/to/squid/libexec/log_mysql_daemon.pl

   The script must be copied to the location specified in the directive.

Database configuration

   Let's call the database 'squid_log' and the log table 'access_log'. The username and
   password for the db connection will be both 'squid'.

  Database

   Create the database:

   CREATE DATABASE squid_log;

  User

   Create the user:

   GRANT INSERT,SELECT ON squid_log.* TO 'squid'@'localhost' IDENTIFIED BY 'squid';
   FLUSH PRIVILEGES;

   Note that only INSERT and SELECT privileges are granted to the 'squid' user. This
   ensures that the logfile daemon script cannot change or modify the log entries.

  Tables and views

   Create the log table and some sample views by using the provided sql scripts:

   cat log_mysql_daemon-table.sql log_mysql_daemon-views.sql | mysql -u root -p squid_log

     ------------------------------------------------------------------------------------

                                     VERSION INFORMATION

   This document refers to log_mysql_daemon.pl script version 0.2.

     ------------------------------------------------------------------------------------

                                       DATA EXTRACTION

   Please see the provided log_mysql_daemon-views.sql

Speed issues

   The myisam storage engine is known to be faster than the innodb one, so although it
   doesn't support transactions and referential integrity, it think it's more appropriate
   in this scenario. If want to change this, open log_mysql_daemon-table.sql and edit the
   "ENGINE=MYISAM" directive.

   Indexes should be created according to the queries that are more frequently run. The DDL
   script only creates an implicit index for the primary key column.

     ------------------------------------------------------------------------------------

                                         BUGS & TODO

Squid version

   This script exploit the logfile_daemon feature implemented in current squid 2 version.

   Squid 3 doesn't have this feature, therefore this script can't be used with squid 3
   installations. UPDATE: Squid 3.HEAD has reintroduced logfile_daemon support. This script
   has been tested with Squid 3.HEAD-20100601.

Table cleanup

   This script currently implements only the L command (i.e. "append a line to the log"),
   therefore the log lines are never purged from the table. This approach has an obvious
   scalability problem.

   One solution would be to implement e.g. the "rotate log" command in a way that would
   calculate some summary values, put them in a "summary table" and then delete the lines
   used to caluclate those values.

   Similar cleanup code could be implemented in an external script and run periodically
   independently from squid log commands.

Testing

   This script has been tested in low-volume scenarios (20 clients, less than 10 req/s).
   Tests in high volume environments could reveal performance bottlenecks and bugs.

     ------------------------------------------------------------------------------------

                                         DEPENDENCIES

   This script requries the following Perl modules:

   DBI

   English

   Readonly

   Carp

   URI

     ------------------------------------------------------------------------------------

                                          CHANGELOG

   v0.2

           Store only domain:port instead of the entire url of each request.

           Added a couple of views to obtain the most requested and traffic-generating
           domains.

   v0.1

           Initial release.

     ------------------------------------------------------------------------------------

                                            AUTHOR

   Marcello Romani, marcello.romani@libero.it

     ------------------------------------------------------------------------------------

                                    COPYRIGHT AND LICENSE

   Copyright (C) 2008 by Marcello Romani

   This library is free software; you can redistribute it and/or modify it under the same
   terms as Perl itself, either Perl version 5.8.8 or, at your option, any later version of
   Perl 5 you may have available.
