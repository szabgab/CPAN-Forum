package CPAN::Forum::Usergroups;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('usergroups');
__PACKAGE__->columns(All => qw/id name/);


1;

