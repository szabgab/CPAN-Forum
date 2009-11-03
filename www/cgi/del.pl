#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use DBI;

my $q = CGI->new;
my $dbfile = '/var/www/cpanforum.com/live/db/forum.db';
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
my $name = $q->param('name');
print $q->header;

my @users = qw(nationshoes njgoogle wowpowerlvl gdoit shoesgreat jordan2008 pickcounty cnbearing);
push @users, qw(rainyjin angelae8654 nisha jojokinkaid billy001 papu);
my $sql = "delete from posts where id in (select posts.id from posts, users where username ";
$sql .=   "in(" . join ", ", map {"'$_'"} @users;
$sql .=  ") and posts.uid=users.id)";
#print $sql;
$dbh->do($sql);
print "OK";

__END__
if (not defined $name or $name eq '') {
  print "Need name";
  exit 0;
}

if ($name =~ /\W/) {
   print "Bad name";
   exit 0;
}
print "OK $name\n";

