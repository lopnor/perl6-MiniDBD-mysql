use v6;
use Test;
use t::lib;

ok my $dbh = t::lib::dbh, 'got dbh';

{
    ok $dbh.do('drop table if exists minidbd_mysql_test'), 'drop table if exists';
}
{
    ok my $sth = $dbh.prepare(q{
        create table minidbd_mysql_test(
            id int not null primary key auto_increment,
            data text
        ) default  charset utf8
    }), 'create table prepare';
    ok $sth.execute, 'create table execute';
}
{
    ok my $sth1 = $dbh.prepare('select * from minidbd_mysql_test where id = ?');
    ok my $sth2 = $dbh.prepare('insert into minidbd_mysql_test (data) values (?)');

    for <ほげ ふが> -> $data {
        ok $sth2.execute($data), 'insert execute';
        ok my $id = $dbh.mysql_insertid;
        ok $sth1.execute($id), 'select execute';
        ok my $row = $sth1.fetchrow_hashref;
        is_deeply $row, {
            id => "$id",
            data => "$data",
        };
    }
}

{
    ok $dbh.do('drop table minidbd_mysql_test');
}

done;

# vim: ft=perl6 :
