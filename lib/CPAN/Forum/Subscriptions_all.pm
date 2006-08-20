package CPAN::Forum::Subscriptions_all;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('subscriptions_all');
__PACKAGE__->columns(All => qw/id uid allposts starters followups announcements/);
__PACKAGE__->has_a(uid => "CPAN::Forum::Users");

1;
