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

{
	my $authors = $src->selectall_arrayref("SELECT id, pauseid FROM authors");
	my $sth = $to->prepare("INSERT INTO authors (id, pauseid) VALUES (?, ?)");
	print "Authors: " . scalar(@$authors) . "\n";
	foreach my $d (@$authors) {
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

{
	my $users = $src->selectall_arrayref("SELECT id, username, email, fname, lname, update_on_new_user, password FROM users");
	my $sth = $to->prepare("INSERT INTO users (id, username, email, fname, lname, update_on_new_user, sha1) 
			VALUES (?, ?, ?, ?, ?, ?, ?)");
	print "Users: " . scalar(@$users) . "\n";
	foreach my $d (@$users) {
		my $pw = sha1_base64(pop @$d);
		next if $d->[0] == 1;   # skip the admin user as it is already in the database

		#print "@$d\n";
		#exit if $main::i++ > 10;
		eval {
			$sth->execute(@$d, $pw);
		};
		if($@) {
			print "row @$d\n";
			die $@;
		}

	}
}
# 12 sec up till here


#my $groups = $src->selectall_arrayref("SELECT * FROM groups");
#print scalar @$groups;
#foreach my $g (@$groups) {
#}
