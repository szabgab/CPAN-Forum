#!/usr/bin/perl

use strict;
use warnings;

use Cwd            qw(abs_path cwd);
use File::Basename qw(dirname);
use File::Path     qw(mkpath);
use Getopt::Long   qw(GetOptions);

use lib dirname(dirname(abs_path($0))) . '/lib';

use CPAN::Forum::INC;

my %opts;
GetOptions(\%opts, "config=s", "dbfile=s") or die;
die "$0 --config CONFIG --dbfile DB_FILE\n" 
    if not $opts{config} or not $opts{dbfile};

my $dir = dirname($opts{dbfile});

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

mkpath($dir);
unlink $opts{dbfile};
CPAN::Forum::DBI->myinit("dbi:SQLite:$opts{dbfile}");
CPAN::Forum::DBI->init_db("schema/schema.sql", $opts{dbfile});
print "Turning database directory and database word writable, for now\n";
chmod 0777, $dir;
chmod 0777, $opts{dbfile};


my $from = delete $opt{from};
CPAN::Forum::DB::Configure->set_field_value('from', $from);

CPAN::Forum::DB::Users->add_user({id => 1, update_on_new_user => 1, %opt});
CPAN::Forum::DB::Users->update(1, password => $opt{password});

CPAN::Forum::DB::Users->add_usergroup({id => 1, name => "admin"});
CPAN::Forum::DB::Users->add_user_to_group(uid => 1, gid => 1);


