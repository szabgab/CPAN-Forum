package CPAN::Forum::DB::GroupRelations;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('grouprelations');
__PACKAGE__->columns(All => qw/parent child/);
__PACKAGE__->has_a(parent => "CPAN::Forum::DB::Groups");
__PACKAGE__->has_a(child  => "CPAN::Forum::DB::Groups");

1;
