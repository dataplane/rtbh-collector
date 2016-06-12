#!/usr/bin/perl -T
use warnings;
use strict;

# $Id: $

use DBD::Pg;
use English;
use HTML::Parser;
use HTTP::Request::Common;
use HTTP::Response;
use HTTP::Status qw( :constants :is status_message );
use LWP::UserAgent;
use POSIX qw( strftime );
use Readonly;

$OUTPUT_AUTOFLUSH = 1;

Readonly my $BASE_URL     => 'https://lg.de-cix.net/#neighbour_info';
Readonly my $ROUTE_SERVER => 'rs1-active.de-cix.net';
Readonly my $NEXT_HOP     => '80.81.193.66';
Readonly my $DATA_SOURCE  => 'DE-CIX';
Readonly my $STAMP        => strftime "%Y-%m-%d %H:%M", gmtime();

my $ua = LWP::UserAgent->new;
$ua->ssl_opts( verify_hostname => 0 );    # WARNING: allow invalid cert

my $res = $ua->request(
    POST $BASE_URL,
    [
        query       => 'show ip bgp neighbor',
        tab         => 'neighbour_info',
        routeserver => $ROUTE_SERVER,
        argument    => $NEXT_HOP,
        submit      => 'Submit',
    ]
);

my $res_message = $res->message;
my $res_code    = $res->code;
if ( !$res->is_success ) {
    print "FAILURE: unexpected HTTP response ($res_code $res_message)\n";
    next;
}

my $content = $res->decoded_content();

# As of 2016-05, HTML output we are looking for:
#   <div id="output">
#   <pre>
#   > sh ip bgp neighbor 80.81.193.66 route
#   BGP table
#   Status codes: * valid, > best
#   Origin codes: i - IGP, e - EGP, ? - incomplete
#   
#      Network                Next Hop         Metric LocPrf Weight Path
#   *> 62.219.90.194/32       80.81.193.66               100        8551 ?
#   *> 199.203.35.242/32      80.81.193.66               100        1680 i
#   *> 88.87.0.1/32           80.81.193.66               100        57344 34754 i
#   *> 82.166.210.6/32        80.81.193.66               100        1680 i
#   *> 87.119.203.208/32      80.81.193.66          0    100        25074 ?
# [...]

my $parser  =  HTML::Parser->new( start_h => [ \&default_start, 'self,tagname' ] );
$parser->parse($content);

my $dbh = db_connect();
my ( $sql, $sth );

for my $route ( keys %{$parser->{rtbh}} ) {
    my $origin = $parser->{rtbh}{$route};

    $sql = 'INSERT INTO blackhole (route,origin,stamp,data_source) VALUES (?, ?, ?, ?)';

    $sth = $dbh->prepare($sql) or die 'db preparation error: ' . DBI->errstr;
    $sth->execute( $route, $origin, $STAMP, $DATA_SOURCE ) or die 'db execute error: ' . DBI->errstr;
}

$sth->finish or die 'db finish error: ' . DBI->errstr;
db_disconnect($dbh);

exit 0;

sub default_start {
    my ( $self, $tagname ) = @_;

    if ( $tagname eq 'pre' ) {
        $self->handler( text => \&get_text, 'self,dtext' );
        $self->handler( end  => \&end_text, 'self,tagname' );
    }

    return;
}

sub get_text {
    my ( $self, $text ) = @_;

    for my $line ( split /^/, $text ) {
        chomp $line;

        next if $line !~ m{ \A [*][>] \s ( \d{1,3} (?: [.] \d{1,3} ){3} [/] \d{1,2} ) \s+ $NEXT_HOP \s }xms; 

        my $route = $1;

        next if $line !~ m{ \s+ 100 \s+ ( (?: \d{1,10} \s ){1,} [\?|i] ) \z }xms;
        my $path = $1;
        my @asns = split /\s/, $path;
        my $origin = $asns[-2];

        $self->{rtbh}{$route} = $origin;
    }
 
    return;
}

sub end_text {
    my ( $self, $tagname ) = @_;

    if ( $tagname eq 'pre' ) {
        $self->handler( text => '' );
        $self->handler( start => '' );
        $self->handler( end => '' );
    }

    return;
}

sub db_connect {
    my ($arg_ref) = @_;
    my $db_type = $arg_ref->{type} || 'Pg';
    my $db_host = $arg_ref->{host} || '127.0.0.1';
    my $db_port = $arg_ref->{port} || 5432;
    my $db_user = $arg_ref->{user} || '';
    my $db_pass = $arg_ref->{pass} || '';
    my $db_name = $arg_ref->{db}   || 'dataplane';
    my $db_dsn  = "DBI:$db_type:dbname=$db_name;host=$db_host;port=$db_port";

    my $dbh = DBI->connect( $db_dsn, $db_user, $db_pass )
        || die 'db_connect error: ' . DBI->errstr;

    return $dbh;
}

sub db_disconnect {
    my $dbh = shift || return;

    $dbh->disconnect or die 'db disconnect error: ' . DBI->errstr;

    return;
}
