#!/usr/bin/perl
use strict;
use warnings;

use lib "lib";

use File::Copy qw(move copy);
use Getopt::Long qw(GetOptions);
use DBI;
use Cwd qw(cwd);

# tell application db is closed...

my %opts;
GetOptions(\%opts, "dir=s") or die;
die "$0 --dir DB_DIR\n" 
    if not $opts{dir};

my $time   = time;
my $failed;
my $db_file = "$opts{dir}/forum.db";
my $backup = $db_file . "_$time";
print "Backup: $backup\n";
copy $db_file, $backup;
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file") 
    or die "Could not connect to database";
my $source = do {
    local $/ = undef;
    <DATA>;
};

foreach my $sql (split /;/, $source) {
    next if $sql !~ /\S/;
    $dbh->do($sql);
}
#$failed = 1;
{
    my $sth_select = $dbh->prepare("SELECT id, username FROM users");
    $sth_select->execute();
    my %uid_of;
    while (my $h = $sth_select->fetchrow_hashref('NAME_lc')) {
        $uid_of{ $h->{username} } = $h->{id};
    }

    my $sth_get_posts = $dbh->prepare("SELECT * FROM posts_old ORDER BY id");
    my $sth_insert_post = $dbh->prepare("INSERT INTO posts VALUES(?,?,?,?,?,?,?,?,?)");

    $sth_get_posts->execute;
    while (my $h = $sth_get_posts->fetchrow_hashref('NAME_lc')) {
        $sth_insert_post->execute(
                $h->{id}, $h->{gid}, $uid_of{ $h->{uid} },
                $h->{parent}, $h->{thread}, $h->{hidden}, $h->{subject},
                $h->{text}, $h->{date});
    }
    $dbh->do("DROP TABLE posts_old");
}

$dbh->do("VACUUM");

if ($failed) {
	print "Upgraded failed.\n";
    unlink $db_file;
	move $backup, $db_file;
	print "Database restored\n";
} else {
	print "The datbase was upgraded successfully.\n";
	
}
# set the application to "open" again

__END__
ALTER TABLE groups ADD version VARCHAR(100);
ALTER TABLE groups ADD pauseid INTEGER;
ALTER TABLE groups ADD rating VARCHAR(10);
ALTER TABLE groups ADD review_count INTEGER;

CREATE TABLE subscriptions_all (
			id               INTEGER PRIMARY KEY,
			uid              INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN
);

CREATE TABLE authors (
			id               INTEGER PRIMARY KEY,
			pauseid          VARCHAR(100) UNIQUE NOT NULL
);

DROP TABLE sessions;
ALTER TABLE posts RENAME TO posts_old;
CREATE TABLE posts (
			id               INTEGER PRIMARY KEY,
			gid              INTEGER NOT NULL,
			uid              INTEGER NOT NULL,
			parent           INTEGER,
			thread           INTEGER,
			hidden           BOOLEAN,
			subject          VARCHAR(255) NOT NULL,
			text             VARCHAR(100000) NOT NULL,
			date             TIMESTAMP
);

CREATE TABLE subscriptions_pauseid (
			id               INTEGER PRIMARY KEY,
			uid              INTEGER NOT NULL,
			pauseid          INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN
);


