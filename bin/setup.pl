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
GetOptions(\%opts, 
	'dbname=s', 
	'dbuser=s',

	'username=s',
	'email=s',
	'password=s',
	'from=s',
) or usage();

$opts{dbname} ||= $ENV{CPAN_FORUM_DB};
$opts{dbuser} ||= $ENV{CPAN_FORUM_USER};

usage() if not $opts{dbname} or not $opts{dbuser};

usage() if not $opts{username} 
	or not $opts{password} 
	or not $opts{email} 
	or not $opts{from};

$ENV{CPAN_FORUM_DB}   = $opts{dbname};
$ENV{CPAN_FORUM_USER} = $opts{dbuser};

CPAN::Forum::DBI->myinit();
CPAN::Forum::DBI->init_db();


my $from = delete $opts{from};
CPAN::Forum::DB::Configure->set_field_value('from', $from);

CPAN::Forum::DB::Users->add_user({id => 1, update_on_new_user => 1, %opts});
CPAN::Forum::DB::Users->update(1, password => $opts{password});

CPAN::Forum::DB::Users->add_usergroup({id => 1, name => "admin"});
CPAN::Forum::DB::Users->add_user_to_group(uid => 1, gid => 1);


sub usage {

	print <<"USAGE";

Usage: $0
      --dbname DB_NAME   or set the environment variable CPAN_FORUM_DB
      --dbuser DB_USER   or set the environment variable CPAN_FORUM_USER


      Admin user of CPAN::Forum
      --username USERNAME       
      --email EMAIL
      --password PASSWORD
      
      --from EMAIL         When sending e-mail what should be the From: fields

USAGE

	exit;
}