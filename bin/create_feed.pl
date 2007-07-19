#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use Text::CSV_XS;
use Cwd           qw(cwd);

use lib "lib";

use CPAN::Forum::DBI;
use CPAN::Forum::DB::Posts;
use CPAN::Forum::DB::Tags;
use CPAN::Forum::DB::Groups;
use CPAN::Forum::DB::Users;

my %opts;
GetOptions(\%opts, 'help', 'dbdir=s', 'out=s') or usage();
usage() if $opts{help};
usage() if not $opts{dbdir} or not $opts{out};


my $dbfile       = "$opts{dbdir}/forum.db";
CPAN::Forum::DBI->myinit("dbi:SQLite:$dbfile");

posts_count_csv();
tags();
db_dump();
exit;

sub posts_count_csv {
    my $csv          = Text::CSV_XS->new();

    open my $out, '>', "$opts{out}/cpanforum.csv" or die $!;
    my $ar = CPAN::Forum::DB::Posts->list_counted_posts;
    foreach my $entry (@$ar) {
        if ($csv->combine($entry->{gname}, $entry->{cnt})) {
            print {$out} $csv->string(), "\n";
        } else {
            warn "Invalid row";
        }
    }
}


sub tags {
    my $ar = CPAN::Forum::DB::Tags->list_modules_and_tags;
    my %data;
    foreach my $hr (@$ar) {
	    push @{ $data{ $hr->{module} } }, $hr->{tag};
    }
    open my $out, '>', "$opts{out}/module_tags.csv" or die $!;
    foreach my $module (sort keys %data) {
	    print $out join ",", $module, @{ $data{$module} };
	    print $out "\n";
    }
    close $out;
    system "/bin/bzip2 -f $opts{out}/module_tags.csv";
}

sub db_dump {
    my $cwd = cwd;
    mkdir "$opts{out}/cpanforum";
    chdir "$opts{out}/cpanforum";

    _save_file("tags.csv",      "id,name",            CPAN::Forum::DB::Tags->dump_tags);
    _save_file("tag_cloud.csv", "uid,tag_id,dist_id", CPAN::Forum::DB::Tags->dump_tag_cloud);
    _save_file("dists.csv",     "id,name",            CPAN::Forum::DB::Groups->dump_groups);
    _save_file("users.csv",     "id,username",        CPAN::Forum::DB::Users->dump_users);

    chdir $cwd;
    chdir $opts{out};
    system "/bin/tar cjf db_dump.tar.bz2 cpanforum"; 
}

sub _save_file {
    my ($file, $header, $ar) = @_;

    open my $out, '>', $file or die "Could not open '$file': $!";
    print $out "$header\n";
    foreach my $r (@$ar) {
        print $out join ",", @$r;
        print $out "\n";
    }
}

sub usage {

    print <<"END_USAGE";

Usage: $0
        --help             this help
        --dbdir  DIR       directory of forum.db file
        --out  DIR         path to the output directory
END_USAGE
    exit;
}




