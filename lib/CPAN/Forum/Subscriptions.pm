package CPAN::Forum::Subscriptions;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('subscriptions');
__PACKAGE__->columns(All => qw/id gid uid allposts starters followups announcements/);
__PACKAGE__->has_a(uid => "CPAN::Forum::Users");
__PACKAGE__->has_a(gid => "CPAN::Forum::Groups");

1;
