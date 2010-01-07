package t::lib::CPAN::Forum::Test;
use strict;
use warnings;

use Cwd            qw(abs_path cwd);
use File::Basename qw(dirname);
use File::Copy     qw(copy);
use File::Path     qw(mkpath);
use File::Temp     qw(tempdir);
use CPAN::Faker;


my $ROOT = dirname(dirname(dirname(dirname(dirname(abs_path(__FILE__))))));

our %admin = (
        username => 'testadmin',
        email    => 'test@perl.org.il',
        password => 'pw_of_testadmin',
        from     => 'testforum@perl.org.il',
    );

our @users = (
    {
        username => 'abcder',
        email    => 't@cpanforum.com',
    },
    {
        username => 'zorgmaster',
        email    => 'z@cpanforum.com',
    },
);

sub setup_database {
    $ENV{CPAN_FORUM_DB}   = $ENV{CPAN_FORUM_TEST_DB};
    $ENV{CPAN_FORUM_USER} = $ENV{CPAN_FORUM_TEST_USER};

    # TODO capture STDERR and show if there was an error
    my $out = qx{$^X bin/setup.pl    --email $admin{email} --username $admin{username} --password $admin{password} --from $admin{from} 2>&1};
    if ($out =~ /ERROR/) {
        die $out;
    }
    
    my $dir = build_fake_cpan();
    system "$^X bin/populate_cpan_forum.pl --cpan file://$dir --mirror mini --process all --yaml";

    return;
}

sub init_db {
    require CPAN::Forum::DBI;
    $ENV{CPAN_FORUM_DB}   = $ENV{CPAN_FORUM_TEST_DB};
    $ENV{CPAN_FORUM_USER} = $ENV{CPAN_FORUM_TEST_USER};

    return CPAN::Forum::DBI->myinit();
}

sub get_dbh {
    return init_db();
}

sub register_user {
    my ($id) = @_;

    init_db();
    require CPAN::Forum::DB::Users;
    my $user = CPAN::Forum::DB::Users->add_user($users[$id]);
    return $user;
}

sub register_users {
    my ($id, $n) = @_;

    init_db();
    require CPAN::Forum::DB::Users;
    my @users;
    foreach my $i (1..$n) {
        my %user;
        $user{$_} = $i . $users[$id]{$_} foreach qw(username email);
        push @users, CPAN::Forum::DB::Users->add_user(\%user);
    }
    return @users;
}

sub get_mech {
    # TODO Enable using an environment variable?
    #require Test::WWW::Mechanize;
    #Test::WWW::Mechanize->new;
    
    require Test::WWW::Mechanize::CGI;

    # for some reason the environemnt variable is not visible inside the cgi request
    # so we have to pass them this way:
    my $w = Test::WWW::Mechanize::CGI->new;
    $w->env(
        CPAN_FORUM_LOGFILE => $ENV{CPAN_FORUM_LOGFILE},
        CPAN_FORUM_DB      => $ENV{CPAN_FORUM_TEST_DB},
        CPAN_FORUM_USER    => $ENV{CPAN_FORUM_TEST_USER},
    );

    $w->cgi(sub {
        require CPAN::Forum;

        my $webapp = CPAN::Forum->new(
                TMPL_PATH => "templates",
                PARAMS => {
                    ROOT       => $ROOT,
                },
            );
        $webapp->run();
        }); 
    return $w;
};

sub CPAN::Forum::_test_my_sendmail {
    my %mail = @_;
    my @fields = qw(Message From Subject To);
    my %m;
    @m{@fields} = @mail{@fields};
    push @CPAN::Forum::messages, \%m;
    return;
}

sub build_fake_cpan {
    my $dir = tempdir( CLEANUP => 1 );
    mkdir $dir;
    my $cpan = CPAN::Faker->new({
	source => "$ROOT/testfiles/fakepan_src_1",
	dest   => $dir,
    });
    $cpan->make_cpan;

    return $dir;
}

1;

