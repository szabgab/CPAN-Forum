package CPAN::Forum::DB::Subscriptions_pauseid;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('subscriptions_pauseid');
__PACKAGE__->columns(All => qw/id pauseid uid allposts starters followups announcements/);
__PACKAGE__->has_a(uid     => "CPAN::Forum::DB::Users");
__PACKAGE__->has_a(pauseid => "CPAN::Forum::DB::Authors");

1;
