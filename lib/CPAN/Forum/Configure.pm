package CPAN::Forum::Configure;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('configure');
__PACKAGE__->columns(All => qw/field value/);


1;



1;

