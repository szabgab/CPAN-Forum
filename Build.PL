use strict;
use warnings;

use lib "lib";
use FindBin qw($Bin);

use CPAN::Forum::Build;

my $builder = CPAN::Forum::Build->new(
    module_name         => 'CPAN::Forum',
    license             => 'perl',
    dist_version_from   => 'lib/CPAN/Forum.pm',
	create_readme       => 1,
	create_makefile_pl => 'traditional',
    requires            => {
		'HTML::Template'                        => 2.6,
		'CGI'                                   => 0,
		'CGI::Application'                      => 3.22,
		'CGI::Application::Plugin::Session'     => 0,
		'CGI::Application::Plugin::LogDispatch' => 0,
		
		'Test::More'                            => 0.47,
#		'Test::Warn'                            => 0,
#		'HTML::Lint'                            => 1.26,
#		'Test::HTML::Lint'                      => 1.26,
		'WWW::Mechanize'                        => 0,
#		'Storable'                              => 0,
		'DBI'                                   => 0,
		'DBD::SQLite'                           => 0.31,
		'Class::DBI'                            => 0.96,
#		'Crypt::SSLeay'                         => 0,  # needed for http access to PAUSE
		'Parse::CPAN::Packages'                 => 0,  # for populating and maybe also later ?
		'LWP::Simple'                           => 0,  # for populate
		'XML::RSS::SimpleGen'                   => 0,  # for, well RSS generation
		'Mail::Sendmail'                        => 0,  
    },
	build_requires => {
		'Test::WWW::Mechanize'       => 0.02,
	},
	dist_author => 'Gabor Szabo <gabor@pti.co.il>',
);

$builder->create_build_script();

