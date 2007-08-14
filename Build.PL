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
    create_readme        => 1,
    create_makefile_pl   => 'traditional',
    recursive_test_files => 1,
    requires             => {
        'HTML::Template'                        => 2.6,
        'CGI'                                   => 0,
        'CGI::Application'                      => 3.31,
        'CGI::Application::Plugin::Session'     => 0,
        'CGI::Application::Plugin::LogDispatch' => 0,
        'CGI::Session'                          => 4.13, # 3. 95 generates some warnings on ->flush
        
#       'Test::Warn'                            => 0,
#       'HTML::Lint'                            => 1.26,
#       'Test::HTML::Lint'                      => 1.26,
        'WWW::Mechanize'                        => 0,
        'DBI'                                   => 0,
        'DBD::SQLite'                           => 0.31,
#       'Crypt::SSLeay'                         => 0,  # needed for http access to PAUSE
        'Parse::CPAN::Packages'                 => '2.26',  # for populating and maybe also later ?
        'LWP::Simple'                           => 0,  # for populate
        'XML::RSS::SimpleGen'                   => 0,  # for, well RSS generation
        'XML::Atom::SimpleFeed'                 => 0,
        'Mail::Sendmail'                        => 0,  
        'CGI::Session::SQLite'                  => 0,
        'Parse::RecDescent'                     => 0,
        'Text::CSV_XS'                          => 0,
        'List::MoreUtils'                       => 0,
        'Test::WWW::Mechanize'                  => 0.02,
        'CPAN::DistnameInfo'                    => 0,
    },
    build_requires => {
        'Storable'                              => 0,
        'Test::More'                            => 0.47,
        'Test::WWW::Mechanize::CGI'             => 0,
    },
    dist_author => 'Gabor Szabo <gabor@pti.co.il>',
);

$builder->create_build_script();

