package CPAN::Forum::Test;

use File::Copy qw(copy);

require Exporter;
use vars qw(@ISA @EXPORT);
@ISA    = qw(Exporter);

@EXPORT = qw(@users $ROOT setup_database);

our $ROOT = "blib";  

our @users = (
	{
		username => 'abcder',
		email    => 'qqrq@banana.com',
	},
);

sub setup_database {
	chdir "blib";
	copy "../t/CONFIG", ".";

	system "$^X bin/setup.pl";
	system "$^X bin/populate.pl ../t/02packages.details.txt";

	chdir "..";
}



1;

