use v6;
use Test;
use t::lib;

ok my $dbh = t::lib::dbh;
my $table = 'minidbd_mysql_test';

{
    ok $dbh.do("drop table if exists $table");
    ok $dbh.do( qq{
        create table $table (
            id int not null primary key auto_increment,
            data text
        )
    });
    ok $dbh.do("insert into $table (data) values (?)", 'hoge');
    ok my $id = $dbh.mysql_insertid;
    is $id, 1;
    ok my $sth = $dbh.prepare("select * from $table where id = ?");
    for 1 .. 2 -> $i {
        ok $sth.execute($id), "execute no. $i";
        ok my $row = $sth.fetch, "fetch no. $i";
        is_deeply $row, ["1", "hoge"], "deeply no. $i";
        ok $dbh.disconnect, "disconnect no. $i"; # this is really bad way
    }
}

done;

# vim: ft=perl6 :
