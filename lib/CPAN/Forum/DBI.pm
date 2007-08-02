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
    $dbh->do($sql, undef, @values);
    return;
}    


sub update {
    my ($self, $table, $args, $data) = @_;
    # check if $table is one of the subscription tables?
    my ($where, @values)   = $self->_prep_where($args);
    Carp::croak("") if not $where;
    my ($set, @new_values) = $self->_prep_set($data);
    my $sql = "UPDATE $table SET $set WHERE $where";
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do($sql, undef, @new_values, @values);
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

1;

