package CPAN::Forum::GroupRelations;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('grouprelations');
__PACKAGE__->columns(All => qw/parent child/);
__PACKAGE__->has_a(parent => "CPAN::Forum::Groups");
__PACKAGE__->has_a(child => "CPAN::Forum::Groups");

1;
