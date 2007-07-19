package CPAN::Forum::DBI;
use strict;
use warnings;
use base 'Class::DBI';
use Carp qw(croak);

use Class::DBI::Plugin::AbstractCount;      # pager needs this
use Class::DBI::Plugin::Pager;

use DBI;
my $dbh;

sub myinit {
    my $class = shift;
    my $db_connect = shift;
    if (not $dbh) {
        $dbh = __PACKAGE__->connection($db_connect, '', '', 
                    {
                    });
    }
    return $dbh;
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

1;

