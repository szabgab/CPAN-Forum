#!/usr/bin/perl

use strict;
use warnings;

use File::Copy qw(copy);
use DBI;
use POSIX ();

my $dir = $ARGV[0] or die "Usage: $0 install_dir\n";

my $live   = "$dir/db/forum.db";
my $backup = "$dir/db/backup_" . POSIX::strftime("%Y%m%d_%H%M%S", localtime) . ".db";
my $old    = "$dir/db/old.db";

copy $live, $backup;
copy $live, $old;

# TODO: get the name of the new schema from outside the script
my $schema_file = "schema/schema.sql"; 

open my $fh, "<", $schema_file or die "Cannot open schema file '$schema_file'\n";
my $schema = join "", <$fh>;
close $fh;

my $dbh = DBI->connect("dbi:SQLite:dbname=$live","","");

##########################################################################

#$dbh->do("DROP TABLE person");

foreach my $table (qw(subscriptions_all)) {
	my $sql = fetch_sql("CREATE", $table, $schema);
	restore_and_exit("Could not fetch $table from schema") if not $sql;
	eval {$dbh->do($sql);};
	restore_and_exit() if $@;
}

# some INSERT statements can come here:
=pod
foreach my $sql (
)
{
	eval {$dbh->do($sql);};
	restore_and_exit() if $@;
}
=cut

$dbh->disconnect;


######### and now for copying data from the old database #########

$dbh = DBI->connect("dbi:SQLite:dbname=$live","","");
$dbh->do(qq(ATTACH DATABASE "$old" as old));

=pod
my $sth = $dbh->prepare("select * from old.person");
$sth->execute;
while (my $r = $sth->fetchrow_hashref('NAME_lc')) {
	my (@fields, @values);
	foreach my $f (keys %$r) {
	 	push @fields, $f;
		push @values, $r->{$f};
	}
	my $fields = join(",", @fields);
	my $placeholders = ("?, " x (@fields-1)) . "?";

	#$fields       .= ", announcement";
	#$placeholders .= " ,?";
	#push @values, 11;

	my $sql = "INSERT INTO person ($fields) VALUES ($placeholders)";
	#print $sql;
	my $sth = $dbh->do($sql,  undef, @values);
	#$dbh->do("INSERT INTO users (fname) SELECT fname FROM old.users");
}
=cut

unlink $old;
exit;

#############################################################################

sub fetch_sql {
	my ($type, $table, $schema) = @_;

	my $sql;
	for my $statement (split /;\s*/, $schema) {
		if ($type eq "CREATE") {
			if ($statement =~ /^CREATE\s+TABLE\s+$table/) {
				$sql = $statement;
				last;
			}
		}
		if ($type eq "INSERT") {
			if ($statement =~ /^INSERT\s+INTO\s+$table/) {
				$sql = $statement;
				last;
			}
		}
	}
	return if not $sql;
	$sql =~ s/auto_increment//g;
	$sql =~ s/,?FOREIGN .*$//mg;
	$sql =~ s/TYPE=INNODB//g;
	return $sql;
}

# TODO: What should happen if in the middle of the scipt one of the SQL statements fail ?
#       First of all we need to have log for this
#       Then we probably have to automatically go back to the old database (but then we also should
#       stay with the old code)
sub restore_and_exit {
	my ($msg) = @_;
	print "Restore\n";
	print "$msg\n";
	copy $backup, $live;
	unlink $old;
	exit;
}

