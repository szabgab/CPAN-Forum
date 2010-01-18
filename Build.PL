use strict;
use warnings;

use lib "lib";
use FindBin qw($Bin);

#use CPAN::Forum::Build;
use Module::Build;

#my $builder = CPAN::Forum::Build->new(
my $builder = Module::Build->new(
	module_name          => 'CPAN::Forum',
	license              => 'perl',
	dist_version_from    => 'lib/CPAN/Forum.pm',
	create_readme        => 0,
	create_makefile_pl   => 0,
	recursive_test_files => 1,
	requires             => {
		'autodie'                               => '0',
		'CGI'                                   => 0,
		'CGI::Application'                      => 3.31,
		'CGI::Application::Plugin::Session'     => 0,
		'CGI::Application::Plugin::TT'          => 0,
		'CGI::Application::Plugin::LogDispatch' => 0,
		'CGI::Session'                          => 4.13, # 3.95 generates some warnings on ->flush
		'CPAN::DistnameInfo'                    => 0,
		'CPAN::Mini'                            => '0',

		#       'Crypt::SSLeay'                         => 0,  # needed for http access to PAUSE
		'DBD::Pg'               => '0',
		'DBI'                   => 0,
		'Digest::SHA'           => '0',
		'File::Find::Rule'      => '0',
		'File::HomeDir'         => '0',
		'File::Path'            => '0',
		'File::Temp'            => '0',
		'List::MoreUtils'       => 0,
		'LWP::Simple'           => 0,      # for populate
		'Mail::Sendmail'        => 0,
		'Moose'                 => '0',
		'Parse::CPAN::Packages' => '2.26', # for populating and maybe also later ?
		'Parse::RecDescent'     => 0,
		'Pod::Simple'           => '0',
		'Text::CSV_XS'          => 0,
		'WWW::Mechanize'        => 0,
		'XML::Atom::SimpleFeed' => 0,
		'XML::RSS::SimpleGen'   => 0,      # for, well RSS generation
	},
	build_requires => {
		'CPAN::Faker' => '0.004',

		#       'HTML::Lint'                            => 1.26,
		'Storable' => 0,

		#       'Test::HTML::Lint'                      => 1.26,
		'Test::More' => '0.86',
		'Test::Script' => '0',
		'Test::NoWarnings' => '0',

		#       'Test::Warn'                            => 0,
		'Test::WWW::Mechanize'      => 0.02,
		'Test::WWW::Mechanize::CGI' => '0.1',
		'Test::Most'                => '0.21',
	},
	dist_author => 'Gabor Szabo <gabor@pti.co.il>',
);

$builder->create_build_script();

