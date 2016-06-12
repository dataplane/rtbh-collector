#!/usr/bin/perl -T
use strict;
use warnings;

# $Id: $
# RTB feed report generator

use DBD::Pg;
use English;
use Net::DNS;
use Net::IP;
use POSIX qw(strftime);
use Readonly;

$OUTPUT_AUTOFLUSH++;

Readonly my $START_TIME => strftime "%Y-%m-%d %H:%M", gmtime( time() - 86400 * 7 );
Readonly my $STOP_TIME  => strftime "%Y-%m-%d %H:%M", gmtime();

my $blackhole_ref = get_recent_routes();
@$blackhole_ref = sort { $a->{origin} <=> $b->{origin} } @$blackhole_ref;

print_header();

for my $row (@$blackhole_ref) {
    printf "%-11s  |  %-30s  |  %18s  |  %19s  |  %s\n",
        $row->{origin},
        $row->{origin_name},
        $row->{route},
        $row->{stamp},
        $row->{data_source},
        ;
}

exit 0;

sub get_recent_routes{
    my @routes;

    my $dbh = db_connect();
    my $sql = 'SELECT data_source,route,origin,MAX(stamp) AS stamp FROM blackhole WHERE stamp >= ?'
            . ' GROUP BY data_source,route,origin';

    my $sth = $dbh->prepare($sql) or die 'db preparation error: ' . DBI->errstr;
    $sth->execute($START_TIME) or die 'db execute error: ' . DBI->errstr;

    while( my $row = $sth->fetchrow_hashref() ) {
        push @routes, {
                      origin        => $row->{origin},
                      origin_name   => get_asname($row->{origin}) || 'NA',
                      route         => $row->{route},
                      stamp         => $row->{stamp},
                      data_source   => $row->{data_source},
                    }
        ;
    }

    $sth->finish or die 'db finish error: ' . DBI->errstr;

    db_disconnect($dbh);

    return \@routes;
}

sub print_header {
    print "# NANOG 67 Hackathon - Black Hole Route Feed\n";
    print "# $START_TIME - $STOP_TIME\n";
    print <DATA>;
    return;
}

sub get_asname {
    my $asn   = 'AS' . shift;
    my $res   = Net::DNS::Resolver->new;
    my $qname = $asn . '.asn.cymru.com.';
    my $query = $res->send( $qname, 'TXT' );
    my $as_name;

    return 'NA' if !$query;
    return 'NA' if $query->header->ancount != 1;

    # we will only loop once due to prior ancount test
    for my $answer ( $query->answer ) {
        # WARNING: ASname field could be blank
        my @fields = split /\|/, $answer->rdatastr;
        # remove leading and trailing space
        $fields[4] =~ s{ \A \s* }{}xms;
        $fields[4] =~ s{ \s* \Z }{}xms;
        $fields[4] =~ s{ ["] \Z}{}xms;
        $as_name = substr $fields[4], 0, 30;
    }

    return $as_name || 'NA';
}

sub get_ptr_cymru_whois {
    my $addr = shift || return;

    if ( $addr =~ /:/ ) {
        $addr  = substr new Net::IP ($addr)->reverse_ip, 0, -10;
        $addr .= '.origin6.asn.cymru.com';
    }
    else {
        $addr  = join( '.', reverse split( /\./, $addr ) );
        $addr .=  '.origin.asn.cymru.com';
    }

    return $addr;
}

sub db_connect {
    my ($arg_ref) = @_;
    my $db_type = $arg_ref->{type} || 'Pg';
    my $db_host = $arg_ref->{host} || '127.0.0.1';
    my $db_port = $arg_ref->{port} || 5432;
    my $db_user = $arg_ref->{user} || '';
    my $db_pass = $arg_ref->{pass} || '';
    my $db_name = $arg_ref->{db}   || 'hackathon';
    my $db_dsn = "DBI:$db_type:dbname=$db_name;host=$db_host;port=$db_port";

    my $dbh = DBI->connect( $db_dsn, $db_user, $db_pass )
      || die 'db_connect error: ' . DBI->errstr;

    return $dbh;
}

sub db_disconnect {
    my $dbh = shift || return;

    $dbh->disconnect or die 'db disconnect error: ' . DBI->errstr;

    return;
}

__DATA__
#
# The black hole report is for free for non-commercial use ONLY.
#
# The report format is as follows:
#
# ASN  |  ASname  |  route  |  utc  |  datasrc
#
# Each field is described below.  Please note any special formatting
# rules to aid in processing this file with automated tools and scripts.
# Blank lines may be present to improve the visual display of this file.
# Lines beginning with a hash ('#') character are comment lines.  All
# other lines are report entries.  Each field is separated by a pipe
# symbol ('|') and at least two whitespace characters on either side.
#
#   ASN       Autonomous system number originating a route for the entry
#             IP address. Note, 4-byte ASNs are supported and will be
#             displayed as a 32-bit integer.
#
#   ASname    A descriptive network name for the associated ASN.  The
#             name is truncated to 30 characters.
#
#   route     The black hole route that is being reported.
#
#   utc       A last seen timestamp formatted as YYYY-MM-DD HH:MM:SS
#             and in UTC time.
#
#   datasrc   The source of the blackhole route.  Thsi will be an ISP
#             or IX name.
#
