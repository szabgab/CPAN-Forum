package CPAN::Forum::DB::Authors;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('authors');
__PACKAGE__->columns(All => qw/id pauseid/);
__PACKAGE__->has_many(uid => "CPAN::Forum::DB::Groups");
__PACKAGE__->has_many(subscriptions => "CPAN::Forum::DB::Subscriptions_pauseid");

1;
