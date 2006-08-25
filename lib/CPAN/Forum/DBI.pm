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

1;

