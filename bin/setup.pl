#!/usr/bin/perl

use strict;
use warnings;
use lib "lib";
use CPAN::Forum::INC;
use FindBin qw($Bin);
use Cwd qw(cwd);

my %opt;
open my $opt, "$Bin/../CONFIG" or die "You need to create a CONFIG file. See README.\n";
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

my $dir = "$Bin/../db";
my $dbfile = "$dir/forum.db";
my $modules = "$dir/modules.txt";
unlink $dbfile if -e $dbfile;
unlink $modules if -e $modules;
mkdir $dir if not -e $dir;
CPAN::Forum::DBI->myinit($dbfile);
CPAN::Forum::DBI->init_db($dbfile);
chmod 0755, $dbfile;


my $from = delete $opt{from};
CPAN::Forum::Configure->create({field => 'from', value => $from});

my $user = CPAN::Forum::Users->create({id => 1, %opt});
$user->password($opt{password});
$user->update;
CPAN::Forum::Usergroups->create({id => 1, name => "admin"});
CPAN::Forum::UserInGroup->create({uid => 1, gid => 1});


