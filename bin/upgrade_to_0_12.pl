#!/usr/bin/perl
use strict;
use warnings;

use lib "lib";

use File::Copy qw(move copy);
use DBI;
use Cwd qw(cwd);

# tell application db is closed...

my $time   = time;
my $failed;
my $db_file = 'db/forum.db';
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

