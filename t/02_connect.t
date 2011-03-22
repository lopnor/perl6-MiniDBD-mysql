use v6;
use Test;
use t::lib;

ok my $dbh = t::lib::dbh;
is $dbh.WHAT, 'MiniDBD::mysql::Connection()';

my $client = $dbh.mysql_client;
ok defined $client;
ok $dbh.disconnect;

done;

# vim: ft=perl6 :
