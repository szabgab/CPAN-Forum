package CPAN::Forum::Configure;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('configure');
__PACKAGE__->columns(All => qw/field value/);


sub param {
	my ($self, $field, $value) = @_;

	my ($handle) = CPAN::Forum::Configure->search({field => $field});
	return $handle->value if $handle;
	return;
}


1;

