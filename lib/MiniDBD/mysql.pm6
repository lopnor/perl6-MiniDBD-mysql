use v6;
use NativeCall;
use MiniDBD;

sub mysql_affected_rows( OpaquePointer $mysql_client )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_close( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_error( OpaquePointer $mysql_client)
    returns Str
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_field( OpaquePointer $result_set )
    returns Positional of Str
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_row( OpaquePointer $result_set )
    returns Positional of Str
    is native('libmysqlclient')
    { ... }

sub mysql_field_count( OpaquePointer $mysql_client )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_free_result( OpaquePointer $result_set )
    is native('libmysqlclient')
    { ... }

sub mysql_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_insert_id( OpaquePointer $mysql_client )
    returns Int # WRONG: actually returns an unsigned long long
    is native('libmysqlclient')
    { ... }

sub mysql_query( OpaquePointer $mysql_client, Str $sql_command )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_real_connect( OpaquePointer $mysql_client, Str $host, Str $user,
    Str $password, Str $database, Int $port, Str $socket, Int $flag )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_use_result( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_ping( OpaquePointer $mysql_client )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_options( OpaquePointer $mysql_client, Int $option, Str $arg)
    returns Int
    is native('libmysqlclient')
    { ... }

#-----------------------------------------------------------------------

class MiniDBD::mysql::StatementHandle does MiniDBD::StatementHandle {
    has $!mysql_client is rw;
    has $!statement;
    has $!affected_rows;
    has $!connection;

    method execute(*@params is copy) {
        $!mysql_client = $!connection.mysql_client;
        my $statement = $!statement;
        while @params.elems > 0 and $statement.index('?') >= 0 {
            my $param = self.quote(@params.shift);
            if $param ~~ /<-[0..9]>/ {
                $statement .= subst('?',"'$param'"); # quote non numerics
            }
            else {
                $statement .= subst('?',$param); # do not quote numbers
            }
        }
        $!connection.finish; # clear result_set
        my $status = mysql_query( $!mysql_client, $statement ); # 0 means OK
        if $status != 0 { $!connection.check_mysql_error; }
        my $rows = self.rows;
        return ($rows == 0) ?? "0E0" !! $rows;
    }

    method quote ($str is copy) {
        $str ~~ s:g/"\\"/\\\\/;
        $str ~~ s:g/"\x00"/\\0/;
        $str ~~ s:g/"\n"/\\n/;
        $str ~~ s:g/"\r"/\\r/;
        $str ~~ s:g/"\'"/\\'/;
        $str ~~ s:g/'\"'/'\\"'/;
        $str ~~ s:g/"\x1a"/\\Z/;
        return $str;
    }

    method rows() {
        $!affected_rows //= mysql_affected_rows($!mysql_client);
        $!connection.check_mysql_error;
        return $!affected_rows;
    }

    method fetchrow_array() {
        my @row_array;

        my $result_set =  mysql_use_result( $!mysql_client);
        my $field_count = mysql_field_count($!mysql_client);

        if defined $result_set {
            my $native_row = mysql_fetch_row($result_set); # can return NULL
            $!connection.check_mysql_error;
            
            if $native_row {
                loop ( my $i=0; $i < $field_count; $i++ ) {
                    @row_array.push($native_row[$i]);
                }
            }
            else { $!connection.finish; }
        }
        return @row_array;
    }

    method fetchrow_arrayref() {
        my $row_arrayref;
        $!connection.result.fetch;
    }

    method fetch() { self.fetchrow_arrayref() } # alias according to perldoc DBI

    method fetchall_arrayref() {
        my @all;
        while self.fetchrow_arrayref() -> $row {
            push @all, $row;
        }
        return my $ref = @all;
    }

    method fetchrow_hashref () {
        my $row_hashref;
        my %row_hash;

        unless defined $!result_set {
            $!result_set  = mysql_use_result($!mysql_client);
            $!field_count = mysql_field_count($!mysql_client);
        }

        if defined $!result_set {
            $!connection.check_mysql_error;
            my $native_row = mysql_fetch_row($!result_set); # can return NULL

            unless @!column_names {    
                loop ( my $i=0; $i < $!field_count; $i++ ) {
                    my $field_info  = mysql_fetch_field($!result_set);
                    my $column_name = $field_info[0];
                    @!column_names.push($column_name);    
                }
            }

            if $native_row && @!column_names {
                loop ( my $i=0; $i < $!field_count; $i++ ) {
                    my $column_value = $native_row[$i];
                    my $column_name  = @!column_names[$i];

                    %row_hash{$column_name} = $column_value;
                }
            } else {
                $!connection.finish;
            }

            $row_hashref = %row_hash;
        }
        return $row_hashref;
    }

    method mysql_insertid() {
        $!connection.mysql_insertid;
    }

}

class MiniDBD::mysql::Result {
    has $!mysql_client;
    has $!connection;
    has $!result_set;
    has @!column_names;

    method new ($connection) {
        my $client = $connection.mysql_client;
        my $result_set = mysql_use_result($client);
        my $field_count = mysql_field_count($client);
        my @column_names;
        for ( 1 .. $field_count ) {
            my $field_info = mysql_fetch_field($result_set);
            @column_names.push($field_info[0]);
        }
        self.bless(
            *,
            connection => $connection,
            mysql_client => $client,
            column_names => @column_names,
            result_set => $result_set,
        );
    }

    method fetch {
        my $native_row = mysql_fetch_row($!result_set);
        my $row;
        if $native_row {
            for 1 .. @!column_names.elems -> $i {
                $row[$i] = $native_row[$i];
            }
            return $row;
        } else {
            $!connection.finish;
        }
        return;
    }

    method free {
        mysql_free_result($!result_set);
    }
}

class MiniDBD::mysql::Connection does MiniDBD::Connection {
    has $!mysql_client is rw;
    has $!RaiseError;
    has $!user;
    has $!password;
    has $!params;
    has $!result;

    method mysql_client {
        if (defined $!mysql_client) {
            my $status = mysql_ping($!mysql_client);
            if ($status != 0) {
                self.connect;
                self.check_mysql_error;
            }
        } else {
            self.connect;
        }
        return $!mysql_client;
    }

    method connect {
        unless defined $!mysql_client {
            $!mysql_client = mysql_init( pir::null__P() );
            self.check_mysql_error;
        }
        mysql_options($!mysql_client, 7, 'utf8'); # mysql_use_utf8
        my @params = $!params.split(';');
        my %params;
        for @params -> $p {
            my ( $key, $value ) = $p.split('=');
            %params{$key} = $value;
        }
        my $host     = %params<host>     // 'localhost';
        my $port     = %params<port>     // 0;
        my $database = %params<database> // 'mysql';
        my $result = Q:PIR {
            .local pmc lib
            .local pmc client
            .local pmc result
            .local pmc self
            self = find_lex 'self'
            lib = loadlib 'libmysqlclient'
            $P0 = dlfunc lib, 'mysql_real_connect', 'ppttttiti'
            $P1 = getattribute self, '$!mysql_client'
            client = $P1
            $P1 = find_lex '$host'
            $S0 = $P1
            $P1 = getattribute self, '$!user'
            $S1 = $P1
            $P1 = getattribute self, '$!password'
            $S2 = $P1
            $P1 = find_lex '$database'
            $S3 = $P1
            $P1 = find_lex '$port'
            $I0 = $P1
            null $S4
            result = $P0(client, $S0, $S1, $S2, $S3, $I0, $S4, 0)
            $I1 = defined result
            unless $I1 goto ERR
            branch END
          ERR:
            result = new 'Integer'
            result = 0
          END:
            %r = result
        };
        self.check_mysql_error;
        return 1;
    }

    method result () {
        $!result //= MiniDBD::mysql::Result.new(
            connection => self
        );
        return $!result;
    }

    method finish () {
        if defined( $!result ) {
            $!result.free;
            $!result = Mu;
        }
        return Bool::True;
    }

    method disconnect () {
        self.finish;
        mysql_close($!mysql_client);
        return Bool::True;
    }

    method check_mysql_error {
        my $errstr = mysql_error( $!mysql_client );
        if $errstr && $!RaiseError { die $errstr; }
        return $errstr;
    }

    method prepare( Str $statement ) {
        my $statement_handle = MiniDBD::mysql::StatementHandle.new(
            statement    => $statement,
            connection   => self,
        );
        return $statement_handle;
    }

    method mysql_insertid() {
        mysql_insert_id($!mysql_client);
    }
}

class MiniDBD::mysql {
    method connect( Str $user, Str $password, Str $params, $RaiseError ) {
        my $con = MiniDBD::mysql::Connection.new(
            user => $user,
            password => $password, 
            params => $params,
            RaiseError => $RaiseError
        );
        $con.connect or return;
        return $con;
    }
}
