package CPAN::Forum::Pod;

use Moose;

our $VERSION = '0.20';

extends qw(Pod::Simple::HTML);

#sub _handle_element_start {
#	my ($parser, $element_name, $attr) = @_;
#}
#
#sub _handle_element_end {
#	my ($parser, $element_name) = @_;
#}
#
#sub _handle_text {
#	my ($parser, $text) = @_;
#}

1;
