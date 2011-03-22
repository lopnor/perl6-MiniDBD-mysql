use v6;
use Test;
use MiniDBI;
ok 1;

ok my $dbi = MiniDBI.new;
ok my $driver = $dbi.install_driver('mysql');
is $driver.WHAT, 'MiniDBD::mysql()';

done;

# vim: ft=perl6 :
