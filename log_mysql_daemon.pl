#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use English qw( -no_match_vars );
use Carp qw( carp croak );
use Readonly;
use URI::Split qw(uri_split);
use YAML qw(LoadFile);

our $VERSION = '0.3';

#
# Default values for database connection parameters
#
Readonly my $DEFAULT_HOST     => 'localhost';
Readonly my $DEFAULT_DATABASE => 'squid_log';
Readonly my $DEFAULT_TABLE    => 'access_log';
Readonly my $DEFAULT_USER     => 'squid';
#
# Default path of configuration file
#
Readonly my $DEFAULT_CONFIGFILE => '/etc/squid/log_mysql_daemon.conf';


#
# Global variables
#

# database connection parameters
my ( $host, $database, $table, $user, $pass );


# fields that we should have in the database table
# this list depends on the log format configuration
my @required_fields = qw(
    id
    time_since_epoch
    response_time
    client_src_ip_addr
    squid_request_status
    http_status_code
    reply_size
    request_method
    request_url
    username
    squid_hier_status
    server_ip_addr
    mime_type
);


# config hash
my $config;

# database connection
my $dbh;

# prepared insert statement
my $sth;


#
# Subroutines
#

#
# log_info
#
# utility routine to print messages on stderr (so they appear in cache log)
# without using warn, which would clutter the log with source line numbers
#
sub log_info {
    my $msg = shift;
    print STDERR "$msg\n";
    return;
}



#
# load configuration file
#
sub load_config {
    my $config_file = shift || $DEFAULT_CONFIGFILE;

    log_info("Configuration file: $config_file");

    eval {
        $config = LoadFile($config_file);

        $host = $config->{host};
        $database = $config->{database};
        $table = $config->{table};
        $user = $config->{user};
        $pass = $config->{pass};
    };
    if ($EVAL_ERROR) {
        carp("Error loading config file: $EVAL_ERROR");
    }

    if ( !$host ) {
        $host = $DEFAULT_HOST;
        log_info("Database host not specified. Using '$host'.");
    }
    else {
        log_info("Database host: '$host'");
    }

    if ( !$database ) {
        $database = $DEFAULT_DATABASE;
        log_info("Database name not specified. Using '$database'.");
    }
    else {
        log_info("Database: '$database'");
    }
           
    if ( !$table ) {
        $table = $DEFAULT_TABLE;
        log_info("Table parameter not specified. Using '$table'.");
    }
    else {
        log_info("Table: '$table'");
    }
            
    if ( !$user ) {
        $user = $DEFAULT_USER;
        log_info("User parameter not specified. Using '$user'.");
    }
    else {
        log_info("User: '$user'");
    }

    if ( !$pass ) {
        log_info('No password specified. Connecting with NO password.');
    }
    else {
        log_info("Pass: (hidden)");
    }

    return;
}
              

#
# db_connetct()
#
# Perform database connection
# returns database handle
# or croak()s on error
#
sub db_connect {
    my $dsn = "DBI:mysql:database=$database;host=$host";
    eval {
        log_info("Connecting... dsn='$dsn', username='$user', password='...'");
        $dbh = DBI->connect($dsn, $user, $pass, { AutoCommit => 1, RaiseError => 1, PrintError => 1 });
        carp 'Connected.';
    };
    if ($EVAL_ERROR) {
        croak "Cannot connect to database: $DBI::errstr";
    }

    return $dbh;
}



# a simple test to assure the specified table exists
# and contains at least the required fields
sub check_db_schema {
    my ( $dbh, $db_table, $fields ) = @_;
    eval {
        my $q = 'SELECT ' . join(',',@{ $fields }) . " FROM $db_table LIMIT 1";
        my $sth = $dbh->prepare($q);
        $sth->execute;
        $sth->finish;
    };
    if ($EVAL_ERROR) {
        croak "Error while SELECTing from $table: $DBI::errstr";
    }

    return;
}


# for better performance, the insert statement is prepared only once
sub prepare_insert_statement {
    eval {
        my $q = "INSERT INTO $table (" . join(',',@required_fields) . ") VALUES(NULL" . ',?' x (scalar(@required_fields)-1) . ')';
        $sth = $dbh->prepare($q);
    };
    if ($EVAL_ERROR) {
        croak "Error while preparing sql statement: $EVAL_ERROR";
    }
}


# The script is passed only one argument:
# the path to the configuration file
sub main {
    my $arg = shift;

    load_config($arg);
    $dbh = db_connect();
    check_db_schema($dbh, $table, \@required_fields);

    # for better performance, prepare the statement at startup
    prepare_insert_statement();

    #
    # main loop
    #
    while (my $line = <>) {
        chomp $line;

        my $cmd = substr($line, 0, 1);      # extract command byte
        substr($line, 0, 1, ' ');           # replace command byte with a blank

        if ( $cmd eq 'L' ) {
            my @values = split / \s+ /xms, $line;
            shift @values;                  # the first blank generates an empty bind value that has to be removed
            my ($scheme, $domain, $path, $query, $frag) = uri_split($values[7]);
            $values[7] = $domain || $scheme;
            # debug
            #$values[7] = "scheme=$scheme | domain=$domain | path=$path | query=$query | frag=$frag";
            eval {                          # catch db errors to avoid crashing squid in case something goes wrong...
                $sth->execute(@values) or croak $sth->errstr;
            };
            if ( $EVAL_ERROR ) {
                # leave a trace of the error in cache.log, but don't kill this script with croak...
                carp $EVAL_ERROR . " values=(" . join(', ', @values) . ')';

                # try to recover from lost connection to mysql server
                if ($EVAL_ERROR =~ m/server has gone away/i) {
                    carp 'MySQL server has gone away: trying to reconnect...';
                    eval {
                        $dbh = db_connect();
                        prepare_insert_statement();
                    };
                    if ( $EVAL_ERROR ) {
                        carp $EVAL_ERROR;
                    }
                }
            }
        }
    }

    $sth->finish;
    $dbh->disconnect();

    return;
}


# the first argument passed to this script is the access_log directive's value
main(shift);


__END__

=head1 NAME

C<log_mysql_daemon.pl> - Write squid access log into a mysql database

=head1 SYNOPSIS

  mysql> CREATE DATABASE squid_log;

  mysql -u root -p squid_log < log_mysql_daemon.sql

  cp log_mysql_daemon.pl /path/to/squid/libexec/

then, in squid.conf:

  logformat squid_mysql  %ts.%03tu %6tr %>a %Ss %03Hs %<st %rm %ru %un %Sh %<A %mt

  access_log daemon:/etc/squid/log_mysql_daemon.conf squid_mysql

  logfile_daemon /path/to/squid/libexec/log_mysql_daemon.pl

=head1 DESCRIPTION

This script exploits the new logfile daemon support available in squid 2.7 to store access log entries in a MySQL database.

=head1 CONFIGURATION

=head2 Squid configuration

=head3 logformat directive

This script expects the following log format (it's the default 'squid' log format without the two '/' characters):

  logformat squid_mysql  %ts.%03tu %6tr %>a %Ss %03Hs %<st %rm %ru %un %Sh %<A %mt

=head3 access_log directive

The path to the access log file now specifies the location of the script config file

  access_log daemon:/etc/squid/log_mysql_daemon.conf squid_mysql

The 'daemon' prefix is mandatory and tells squid that the logfile_daemon is to be used instead of the normal file logging.

The path shown here is just an example.

The last parameter, 'squid_mysql' in the example, tells squid which log format to use when writing lines to the log daemon.

=head3 logfile_daemon directive

This is the current way of telling squid where the logfile daemon resides.

  logfile_daemon /path/to/squid/libexec/log_mysql_daemon.pl

The script must be copied to the location specified in the directive.

=head3 Additional settings for squid setups using NTML authentication

When using NTLM Authentication, for every request squid logs two TCP_DENIED/407, which are useless and only help grow even more the database. To prevent logging of these lines add the following lines before the C<access_log> directive:

  acl Auth_Challenge rep_header X-Squid-Error ERR_CACHE_ACCESS_DENIED
  log_access deny Auth_challenge

=head2 Configuration file

The configuration file contains the database connection parameters, written as key: value pairs, one per line.

Example:

  host: localhost
  database: squid_log
  table: access_log
  user: squid
  pass: 123456

(It's a YAML file.)

=over 4

=item host

Host where the mysql server is running. If unspecified, 'localhost' is assumed.

=item database

Name of the database to connect to. If unspecified, 'squid_log' is assumed.

=item table

Name of the database table where log lines are stored. If unspecified, 'access_log' is assumed.

=item username

Username to use when connecting to the database. If unspecified, 'squid' is assumed.

=item password

Password to use when connecting to the database. If unspecified, no password is used.

=back

To leave all fields to their default values, just create the configuration file and don't write anything in it.

To only specify the database password, put this single line in the configuration file:

  pass: <password>

=head3 Security note

This file should be owned by root and its permission bits should be set to 600.

=head2 Database configuration

Let's call the database 'squid_log' and the log table 'access_log'. The username and password for the db connection will be both 'squid'.

=head3 Database

Create the database:

  CREATE DATABASE squid_log;

=head3 User

Create the user:

  GRANT INSERT,SELECT ON squid_log.* TO 'squid'@'localhost' IDENTIFIED BY 'squid';
  FLUSH PRIVILEGES;

Note that only INSERT and SELECT privileges are granted to the 'squid' user. This ensures that the logfile daemon script cannot change or modify the log entries. 

=head3 Tables and views

Create the log table and some sample views by using the provided sql scripts:

C<cat log_mysql_daemon-table.sql log_mysql_daemon-views.sql | mysql -u root -p squid_log>

=head1 VERSION INFORMATION

This document refers to C<log_mysql_daemon.pl> script version 0.3.

=head1 DATA EXTRACTION

Please see the provided log_mysql_daemon-views.sql

=head2 Speed issues

The myisam storage engine is known to be faster than the innodb one, so although it doesn't support transactions and referential integrity, it think it's more appropriate in this scenario. If want to change this, open log_mysql_daemon-table.sql and edit the "ENGINE=MYISAM" directive.

Indexes should be created according to the queries that are more frequently run. The DDL script only creates an implicit index for the primary key column.

=head1 BUGS & TODO

=head2 Squid version

This script exploit the C<logfile_daemon> feature implemented in current squid 2 version.

Squid 3 doesn't have this feature, therefore this script can't be used with squid 3 installations.
UPDATE: Squid 3.HEAD has reintroduced logfile_daemon support. This script has been tested with Squid 3.HEAD-20100601.

=head2 Table cleanup

This script currently implements only the C<L> command (i.e. "append a line to the log"), therefore the log lines are never purged from the table. This approach has an obvious scalability problem.

One solution would be to implement e.g. the "rotate log" command in a way that would calculate some summary values, put them in a "summary table" and then delete the lines used to caluclate those values.

Similar cleanup code could be implemented in an external script and run periodically independently from squid log commands.

=head2 Testing

This script has been tested in low-volume scenarios (20 clients, less than 10 req/s). Tests in high volume environments could reveal performance bottlenecks and bugs.

=head1 DEPENDENCIES

This script requries the following Perl modules:

C<DBI>

C<English>

C<Readonly>

C<Carp>

C<URI>

C<YAML>

=head1 CHANGELOG

=over 4

=item v0.3

Incompatible change: database connection parameters are now specified using a config file. The access_log directive is used to specify the config file absolute path. This change was suggested by Diego Morato, who noticed that database connection credentials could be easily seen by calling ps or top and showing program arguments.

New dependency: YAML.

=item v0.2

Store only domain:port instead of the entire url of each request.

Added a couple of views to obtain the most requested and traffic-generating domains.

Added a view which shows saved traffic as percent of total daily traffic (note: saved bandwidth is better measured by byte hit ratio, see L<http://wiki.squid-cache.org/SquidFaq/InnerWorkings> for more informations).

Updated POD with config directives for ntml-auth squid setups (diego.morato@hotmail.com)

Try to reconnect if mysql server goes away.

Thanks to Diego Morato for his suggestions.

=item v0.1

Initial release.

=back

=head1 AUTHOR

Marcello Romani, marcello.romani@libero.it

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Marcello Romani

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
