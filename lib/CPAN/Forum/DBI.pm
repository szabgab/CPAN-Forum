package CPAN::Forum::DBI;
use strict;
use warnings;
use base 'Class::DBI';
use Carp qw();

use Class::DBI::Plugin::AbstractCount;      # pager needs this
use Class::DBI::Plugin::Pager;

use DBI;
my $dbh_connected;

sub myinit {
    my $class = shift;
    my $db_connect = shift;
    if (not $dbh_connected) {
        $dbh_connected = __PACKAGE__->connection($db_connect, '', '', 
                    {
                    });
        my $dbh = CPAN::Forum::DBI::db_Main();
        #warn $dbh;
        $dbh->{HandleError} = sub { Carp::confess(shift); };
    }
    return $dbh_connected;
}

our @group_types = ("None", "Global", "Field", "Distribution", "Module");
our %group_types;
$group_types{$group_types[$_]} = $_ for (0..$#group_types);

# Initialize the database
sub init_db {
    my ($class, $schema_file, $dbfile) = @_;

    die "No database file supplied" if not $dbfile;

    my $sql;
    my $dbh = $class->db_Main;
    open my $data, "<", $schema_file or die "Coult no open '$schema_file'  $!\n";
    $sql = join('', <$data>);

    for my $statement (split /;/, $sql) {
        if ($dbh->{Driver}{Name} =~ /SQLite/) {
            $statement =~ s/auto_increment//g;
            $statement =~ s/,?FOREIGN .*$//mg;
            $statement =~ s/TYPE=INNODB//g;
        }
        $statement =~ s/\#.*$//mg;    # strip # comments
        $statement =~ s/--.*$//mg;    # strip -- comments
        next unless $statement =~ /\S/;
        eval {$dbh->do($statement)};
        die "$@: $statement" if $@;
    }
    return 1;
}


# helper function for plain DBI calls
sub _fetch_arrayref_of_hashes {
    my ($self, $sql, @args) = @_;

    $CPAN::Forum::logger->debug("SQL:$sql, " . Data::Dumper->Dump([\@args], ['args'])); 
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@args);
    my @values;
    while (my $hr = $sth->fetchrow_hashref) {
        push @values, $hr;
    }
    return \@values;
}
sub _fetch_single_hashref {
    my ($self, $sql, @args) = @_;

    $CPAN::Forum::logger->debug("SQL:$sql, " . Data::Dumper->Dump([\@args], ['args'])); 
    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@args);
    my $hr = $sth->fetchrow_hashref;
    $sth->finish;
    return $hr;
}

sub _fetch_single_value {
    my ($self, $sql, @args) = @_;

    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@args);
    my ($value) = $sth->fetchrow_array;
    $sth->finish;
    return $value;
}

sub _dump {
    my ($self, $sql, %args) = @_;
    my $dbh = CPAN::Forum::DBI::db_Main();
    return $dbh->selectall_arrayref($sql, \%args);
}

sub count_rows_in {
    my ($self, $table) = @_;
    return $self->_fetch_single_value("SELECT COUNT(*) FROM $table");
}

# TODO this selectall_hashref and the _fetch_hashref seem to server very similar
# purposes
sub _selectall_hashref {
    my ($self, $sql, $key, @args) = @_;
    my $dbh = CPAN::Forum::DBI::db_Main();
    return $dbh->selectall_hashref($sql, $key, undef, @args);
}

sub _select_column {
    my ($self, $sql, @args) = @_;
    my $dbh = CPAN::Forum::DBI::db_Main();
    return $dbh->selectcol_arrayref($sql, undef, @args);
}


# given an SQL statement with two columns selected:
# SELECT key, value FROM table WHERE ...;
# returns a hash reference where the keys are built from 
# the first column and the values from the second column
sub _fetch_hashref {
    my ($self, $sql, @args) = @_;

    my $dbh = CPAN::Forum::DBI::db_Main();
    my $sth = $dbh->prepare($sql);
    $sth->execute(@args);
    my %h;
    while (my ($key, $value) = $sth->fetchrow_array) {
        $h{$key} = $value;
    }
    return \%h;
}


# code for the Subscription* tables
sub _complex_update {
    my ($self, $where, $on, $data, $table) = @_;
    if ($on) {
        my $s = $self->find_one(%$where);
        if ($s) {
            $self->update($table, $where, $data);
        } else {
            $self->add($table, {%$data, %$where} );
        }
        
    } else {
        $self->delete($table, $where);
    }
    return;
}

sub add {
    my ($self, $table, $args) = @_;
    # check if $table is one of the subscription tables?
    my ($fields, $placeholders, @values) = $self->_prep_insert($args);
    my $sql = "INSERT INTO $table ($fields) VALUES($placeholders)";
    my $dbh = CPAN::Forum::DBI::db_Main();
    $CPAN::Forum::logger->debug("SQL:$sql, " 
            . Data::Dumper->Dump([\@values], ['values'])
            ); 
    $dbh->do($sql, undef, @values);
    return;
}    


sub update {
    my ($self, $table, $args, $data) = @_;
    # check if $table is one of the subscription tables?
    my ($where, @where_values)   = $self->_prep_where($args);
    Carp::croak("") if not $where;
    my ($set, @new_values) = $self->_prep_set($data);
    my $sql = "UPDATE $table SET $set WHERE $where";
    my $dbh = CPAN::Forum::DBI::db_Main();
    $CPAN::Forum::logger->debug("SQL:$sql, " 
            . Data::Dumper->Dump([\@new_values], ['new_values'])
            . Data::Dumper->Dump([\@where_values], ['where_value'])
            ); 
    $dbh->do($sql, undef, @new_values, @where_values);
    return;
}

sub delete {
    my ($self, $table, $args) = @_;
    my ($where, @values) = $self->_prep_where($args);
    my $sql = "DELETE FROM $table";
    if ($where) {
        $sql .= " WHERE $where";
    }
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do($sql, undef, @values);
    return;
}

# _prep_where({ field => value, field2 => value2 });
# return("field=? AND field2=?",    value, value2);
sub _prep_where {
    my ($self, $args) = @_;
    #Carp::cluck (Data::Dumper->Dump([$args], ['args']));

    my @fields = keys %$args;
    my @FIELDS;
    my @values;
    foreach my $f (@fields) {
        if (not ref $args->{$f}) {
            push @FIELDS, "$f=?";
            push @values, $args->{$f};
        } elsif ('HASH' eq ref $args->{$f}) {
            my @k = keys %{ $args->{$f} };
            Carp::croak("don't know how to handle more than one keys in $f") if @k != 1;
            if ($k[0] eq 'LIKE') {
                push @FIELDS, "$f LIKE ?";
                push @values, $args->{$f}{$k[0]};
            } else {
                Carp::croak("don't know how to handle $k[0] in $f");
            }
        } else {
            Carp::croak("don't know how to handle $args->{$f}");
        }
    }

    my $where = join " AND ", @FIELDS;
    my %args = %$args;
    return ($where, @values); 
}

sub _prep_set {
    my ($self, $args) = @_;
    my @fields = keys %$args;

    my $where = join ", ", map {"$_=?"} @fields;
    my %args = %$args;
    return ($where, @args{@fields}); 
    #return ($where, @{ $args->{@fields} }); 
}


# gets a hash reference of  field names mapped to values
# return 
#    a partial SQL statement of the fieldnames
#    a partial SQL statement of the placeholders
#    list of values matching
#
#    $obj->_prep_insert({ fname => "Foo", lname => "Bar" })
#    returns( "fname, lname",   "?, ?",    "Foo", "Bar" );
sub _prep_insert {
    my ($self, $args) = @_;

    my @fields = keys %$args;
    my $fields = join ", ", @fields;
    my $placeholders = join ", ", (("?") x scalar @fields);
    my %args = %$args;
    return ($fields, $placeholders, @args{@fields}); 
    #return ($fields, $placeholders, @{ $args->{@fields} }); 
}

sub mypager {
    my ($self, %args) = @_;
    my ($where, @values) = $self->_prep_where($args{where});
    $CPAN::Forum::logger->debug("where='$where'");

    my $fetch_sql = "SELECT posts.id, subject, thread, date, username, groups.name group_name FROM posts, users, groups";
    my $count_sql = "SELECT COUNT(*) FROM posts";
    my @fetch_values = @values;

    if ($where) {
        $fetch_sql .= " WHERE $where";
        $count_sql .= " WHERE $where";
    }

    if ($where) {
        $fetch_sql .= " AND ";
    } else {
        $fetch_sql = " WHERE ";
    }
    $fetch_sql .= " users.id=posts.uid AND groups.id=posts.gid";

    my $order_by = $args{order_by};
    $order_by =~ s/^\s*id/posts.id/;
    $fetch_sql .= " ORDER BY $order_by";

    $fetch_sql .= " LIMIT ?";
    my $limit = $args{per_page} || 10;
    push @fetch_values, $limit;

    my $page = $args{page} || 1;
    if ($page > 1) {
        $fetch_sql .= " OFFSET ?";
        push @fetch_values, $limit*($page-1);
    }

    $CPAN::Forum::logger->debug("count_sql='$count_sql' " . Data::Dumper->Dump([\@values], ['values']));
    my $total = $self->_fetch_single_value($count_sql, @values);
    $CPAN::Forum::logger->debug("total='$total'");

    $CPAN::Forum::logger->debug("fetch_sql='$fetch_sql' " . Data::Dumper->Dump([\@fetch_values], ['fetch_values']));
    my $results = $self->_fetch_arrayref_of_hashes($fetch_sql, @fetch_values);
    $CPAN::Forum::logger->debug(Data::Dumper->Dump([$results], ['results']));

    my %pager = (
        total_entries => $total,
        results       => $results,
    );

    return \%pager;
}
1;

