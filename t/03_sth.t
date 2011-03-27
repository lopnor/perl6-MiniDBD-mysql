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
        )
    }), 'create table prepare';
    ok $sth.execute, 'create table execute';
}
{
    ok my $sth = $dbh.prepare('insert into minidbd_mysql_test (data) values (?)'), 'insert prepare';
    ok my $rows = $sth.execute('foobar'), 'insert execute';
    is $rows, 1, 'affected rows';
    is $sth.mysql_insertid, 1, 'mysql_insertid';
}
{
    ok my $sth = $dbh.prepare('select * from minidbd_mysql_test where id = ?'), 'select prepare';
    ok my $rows = $sth.execute(1), 'select execute';
    ok my $row = $sth.fetchrow_arrayref, 'fetchrow_array';
    is_deeply $row, ['1', 'foobar'], 'result is correct';
}
{
    ok my $sth = $dbh.prepare('select * from minidbd_mysql_test where id = ?'), 'select prepare';
    ok my $rows = $sth.execute(1), 'select execute';
    ok my $row = $sth.fetchrow_hashref, 'fetchrow_hashref';
    is_deeply $row, {id => '1', data => 'foobar'}, 'result is correct';
}
{
    ok $dbh.do('insert into minidbd_mysql_test (data) values (?)', 'hogefuga'), 'insert do';
    ok my $sth = $dbh.prepare('select * from minidbd_mysql_test');
    ok $sth.execute;
    is_deeply $sth.fetchall_arrayref, [
        ['1', 'foobar'],
        ['2', 'hogefuga'],
    ];
}
{
    ok $dbh.do('drop table minidbd_mysql_test');
}

done;

# vim: ft=perl6 :
