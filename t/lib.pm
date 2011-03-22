use v6;
use MiniDBI;

module t::lib {
    our sub dbh {
        my $test_dsn = %*ENV<MINIDBI_DSN> || 'MiniDBI:mysql:database=test';
        my $test_user = %*ENV<MINIDBI_USER> || '';
        my $test_password = %*ENV<MINIDBI_PASS> || '';

        MiniDBI.connect($test_dsn, $test_user, $test_password, :RaiseError);
    }
}

# vim: ft=perl6 :
