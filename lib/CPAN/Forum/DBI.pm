package CPAN::Forum::DBI;
use strict;
use warnings;
use base 'Class::DBI';
use Carp qw(croak);

use Class::DBI::Plugin::AbstractCount;      # pager needs this
use Class::DBI::Plugin::Pager;

use DBI;

sub myinit {
	my $class = shift;
	my $dbfile = shift;
	__PACKAGE__->connection("dbi:SQLite:$dbfile", '', '', 
					{
					});
}

our @group_types = ("None", "Global", "Field", "Distribution", "Module");
our %group_types;
$group_types{$group_types[$_]} = $_ for (0..$#group_types);

# Initialize the database
sub init_db {
	my $class = shift;
	my $dbfile = shift;
	die "No database file supplied" if not $dbfile;

	my $sql;
	my $dbh = $class->db_Main;
	$sql = join('', <DATA>);

	for my $statement (split /;/, $sql) {
		if ($dbh->{Driver}{Name} =~ /SQLite/) {
			$statement =~ s/auto_increment//g;
			$statement =~ s/,?FOREIGN .*$//mg;
			$statement =~ s/TYPE=INNODB//g;
		}
		$statement =~ s/\#.*$//mg;    # strip # comments
		$statement =~ s/--.*$//mg;    # strip -- comments
		next unless $statement =~ /\S/;
		eval {$dbh->do($statement)};
		die "$@: $statement" if $@;
	}
	return 1;
}

1;
__DATA__
CREATE TABLE users (
			id               INTEGER PRIMARY KEY auto_increment,
			username         VARCHAR(255) UNIQUE,
			password         VARCHAR(255),
			email            VARCHAR(255) UNIQUE,
			fname            VARCHAR(255),
			lname            VARCHAR(255),
			update_on_new_user VARCHAR(1),
			status           INTEGER
);

CREATE TABLE usergroups (
			id               INTEGER PRIMARY KEY auto_increment,
			name             VARCHAR(255) UNIQUE
);

CREATE TABLE user_in_group (
			uid               INTEGER,
			gid               INTEGER
);

CREATE TABLE configure (
			field             VARCHAR(255),
			value             VARCHAR(255)
);


--CREATE TABLE grouptypes (
--			id               INTEGER PRIMARY KEY auto_increment,
--			name             VARCHAR(255) NOT NULL
--);
-- grouptypes can be   Global/Distribution/Field



CREATE TABLE groups (
			id               INTEGER PRIMARY KEY auto_increment,
			name             VARCHAR(255) UNIQUE NOT NULL,
			status           INTEGER,
			gtype            INTEGER NOT NULL
);

CREATE TABLE grouprelations (
			parent            INTEGER NOT NULL,
			child            INTEGER NOT NULL
			,FOREIGN KEY (parent) REFERENCES groups(id)
			,FOREIGN KEY (child) REFERENCES groups(id)
);

-- grouprelations defined which group belongs to which other group, 
-- In the application level we'll have to implement the restriction so 
-- Global group will have no parent
-- Fields will have Global as parent
-- Distributions will have Fields as parent one child can have several parents
-- Modules (if added) will have Distributions as parents


CREATE TABLE posts (
			id               INTEGER PRIMARY KEY auto_increment,
			gid              INTEGER NOT NULL,
			uid              INTEGER NOT NULL,
			parent           INTEGER,
			thread           INTEGER,
			hidden           BOOLEAN,
			subject          VARCHAR(255) NOT NULL,
			text             VARCHAR(100000) NOT NULL,
			date             TIMESTAMP
			,FOREIGN KEY (gid) REFERENCES groups(id)
			,FOREIGN KEY (uid) REFERENCES users(id)
			,FOREIGN KEY (parent) REFERENCES posts(id)
);

CREATE TABLE subscriptions (
			id               INTEGER PRIMARY KEY auto_increment,
			uid              INTEGER NOT NULL,
			gid              INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN
			,FOREIGN KEY (gid) REFERENCES groups(id)
			,FOREIGN KEY (uid) REFERENCES users(id)
);

CREATE TABLE sessions (
    id               CHAR(32) NOT NULL UNIQUE,
    a_session        TEXT NOT NULL,
    uid              INTEGER
);



