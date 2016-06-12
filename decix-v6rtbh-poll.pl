#!/usr/bin/perl -T
use warnings;
use strict;

# $Id: $

# for debugging
use Data::Dumper;

use English;
use HTML::Parser;
use HTTP::Request::Common;
use HTTP::Response;
use HTTP::Status qw( :constants :is status_message );
use LWP::UserAgent;
use Readonly;

$OUTPUT_AUTOFLUSH = 1;

Readonly my $BASE_URL     => 'https://lg.de-cix.net/#neighbour_info';
Readonly my $ROUTE_SERVER => 'rs1-active.de-cix.net -6';
Readonly my $NEXT_HOP     => '2001:7f8::1a27:66:95';

my $ua = LWP::UserAgent->new;
$ua->ssl_opts( verify_hostname => 0 );    # WARNING: allow invalid cert

# TODO: get current time stamp
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
#   > sh ip bgp neighbor 2001:7f8::1a27:66:95 route
#   BGP table
#   Status codes: * valid, > best
#   Origin codes: i - IGP, e - EGP, ? - incomplete
#
#      Network                Next Hop         Metric LocPrf Weight Path
#   *> 2a02:2e0:fffe::2/128   2001:7f8::1a27:66:95         100        12306 i
#   *> 2a00:e68:1::ffff:ffff/128  2001:7f8::1a27:66:95         100        15743 i
# [...]

my $parser  =  HTML::Parser->new( start_h => [ \&default_start, 'self,tagname' ] );
$parser->parse($content);

#TODO: roll through $parser->{prefix} list
print Dumper($parser);

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

        next if $line !~ m{ \A [*][>] \s ( [a-f0-9:]+ [/] \d{1,3} ) \s+ $NEXT_HOP \s }xms; 

        my $prefix = $1;

        next if $line !~ m{ \s+ 100 \s+ ( (?: \d{1,10} \s ){1,} [\?|i] ) \z }xms;
        my $path = $1;
        my @asns = split /\s/, $path;
        my $origin = $asns[-2];

        $self->{rtbh}{$prefix} = $origin;
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
