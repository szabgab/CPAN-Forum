#!/usr/bin/perl

use strict;
use warnings;
use lib "lib";
use CPAN::Forum::INC;
use Cwd qw(cwd);
use Getopt::Long qw(GetOptions);

my %opts;
GetOptions(\%opts, "config=s", "dir=s") or die;
die "$0 --config CONFIG --dir DB_DIR\n" 
    if not $opts{config} or not $opts{dir};

my %opt;
open my $opt, $opts{config} or die "You need to create a CONFIG file. See README.\n";
while (<$opt>) {
	chomp ;
	my ($k, $v) = split /=/;
	$opt{$k} = $v;
}
close $opt;

if (
	not $opt{username} or 
	not $opt{password} or 
	not $opt{email}
	) {
	print <<END;
Please provide the following values for the administrator:

$0 --username USERNAME  --email EMAIL --password PASSWORD
END

}

my $dbfile = "$opts{dir}/forum.db";
unlink $dbfile if -e $dbfile;
mkdir $opts{dir} if not -e $opts{dir};
CPAN::Forum::DBI->myinit($dbfile);
CPAN::Forum::DBI->init_db("schema/schema.sql", $dbfile);
chmod 0755, $dbfile;


my $from = delete $opt{from};
CPAN::Forum::Configure->create({field => 'from', value => $from});

my $user = CPAN::Forum::Users->create({id => 1, update_on_new_user => 1, %opt});
$user->password($opt{password});
$user->update;
CPAN::Forum::Usergroups->create({id => 1, name => "admin"});
CPAN::Forum::UserInGroup->create({uid => 1, gid => 1});


