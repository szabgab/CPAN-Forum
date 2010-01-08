#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use Digest::SHA1 qw(sha1_base64);
use DBI;

use CPAN::Forum::DBI;

my %opt;
GetOptions(\%opt,
	'dbfile=s',
	'dbname=s',
	'dbuser=s',
);
system "$^X bin/setup.pl --username demo --email email --password demo --from from";
# --dbfile forum.db --dbname $CPAN_FORUM_TEST_NAME --dbuser $CPAN_FORUM_TEST_USER

$ENV{CPAN_FORUM_USER} = $opt{dbuser};
$ENV{CPAN_FORUM_DB}   = $opt{dbname};

my $src = DBI->connect("dbi:SQLite:dbname=$opt{dbfile}");

CPAN::Forum::DBI->myinit();
my $to = CPAN::Forum::DBI::db_Main();

convert('authors', [qw(id pauseid)]);


{
	my $users = $src->selectall_arrayref("SELECT id, username, email, fname, lname, update_on_new_user, password FROM users");
	my $sth = $to->prepare("INSERT INTO users (id, username, email, fname, lname, update_on_new_user, sha1, registration_date) 
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
	print "Users: " . scalar(@$users) . "\n";
	foreach my $d (@$users) {
		my $pw = sha1_base64(pop @$d);
		next if $d->[0] == 1;   # skip the admin user as it is already in the database

		#print "@$d\n";
		#exit if $main::i++ > 10;
		eval {
			$sth->execute(@$d, $pw, undef);
		};
		if($@) {
			print "row @$d\n";
			die $@;
		}

	}
}
# 12 sec up till here

#convert(qw(usergroups id name));    # set in the setup.pl script
convert('user_in_group', [qw(uid gid)] );
#convert(qw(configure field value)); # set in the setup.pl script
convert('groups', [qw(id name gtype version pauseid rating review_count)], sub {
	my $d = shift;
	$d->[-1] ||= 0;
	}); # TODO check the schema, set pauseid to not null??
# 35 sec
convert('posts', [qw(id gid uid parent thread hidden subject text date)], sub {
	my $d = shift;
	$d->[-1] = gmtime($d->[-1]);
	});
# 51 sec


sub convert {
	my ($table, $columns, $sub) = @_;
	my $cols = join ", ", @$columns;
	my $placeholders = join ", ", ("?") x scalar(@$columns);
	my $select = "SELECT $cols FROM $table";
	my $insert = "INSERT INTO $table ($cols) VALUES ($placeholders)";
	print "$select\n";
	print "$insert\n";
#	exit;
	my $data = $src->selectall_arrayref($select);
	my $sth = $to->prepare($insert);
	print "$table: " . scalar(@$data) . "\n";
	foreach my $d (@$data) {
		if ($sub) {
			$sub->($d);
		}
		#print "@$d\n";
		#exit if $main::i++ > 10;
		eval {
			$sth->execute(@$d);
		};
		if($@) {
			print "row @$d\n";
			die $@;
		}
	}
}


#my $groups = $src->selectall_arrayref("SELECT * FROM groups");
#print scalar @$groups;
#foreach my $g (@$groups) {
#}
