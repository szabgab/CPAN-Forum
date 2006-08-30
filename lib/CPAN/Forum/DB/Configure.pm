package CPAN::Forum::DB::Configure;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('configure');
__PACKAGE__->columns(All => qw/field value/);

my %default = (
    flood_control_time_limit => 10,
);


sub param {
    my ($self, $field, $value) = @_;

    my ($handle) = CPAN::Forum::DB::Configure->search({field => $field});
    return $handle->value if $handle;
    return $default{$field} if defined $default{$field};
    return;
}


1;

