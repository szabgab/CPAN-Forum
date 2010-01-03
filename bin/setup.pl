#!/usr/bin/perl

use strict;
use warnings;

use Cwd            qw(abs_path cwd);
use File::Basename qw(dirname);
use Getopt::Long   qw(GetOptions);

use lib dirname(dirname(abs_path($0))) . '/lib';

use CPAN::Forum::INC;

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
CPAN::Forum::DBI->myinit("dbi:SQLite:$dbfile");
CPAN::Forum::DBI->init_db("schema/schema.sql", $dbfile);
print "Turning database directory and database word writable, for now\n";
chmod 0777, $opts{dir};
chmod 0777, $dbfile;


my $from = delete $opt{from};
CPAN::Forum::DB::Configure->set_field_value('from', $from);

CPAN::Forum::DB::Users->add_user({id => 1, update_on_new_user => 1, %opt});
CPAN::Forum::DB::Users->update(1, password => $opt{password});

CPAN::Forum::DB::Users->add_usergroup({id => 1, name => "admin"});
CPAN::Forum::DB::Users->add_user_to_group(uid => 1, gid => 1);


