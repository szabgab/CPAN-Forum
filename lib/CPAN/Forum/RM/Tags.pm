package CPAN::Forum::RM::Tags;
use strict;
use warnings;

our $VERSION = '0.17';

use CPAN::Forum::DB::Tags ();

sub tags {
	my ($self) = @_;

	my $path  = ${ $self->param("path_parameters") }[0] || '';
	my $value = ${ $self->param("path_parameters") }[1] || '';

	# support tag tcp/ip  but not a/b/c
	if ( ${ $self->param("path_parameters") }[2] ) {
		$value .= "/" . ${ $self->param("path_parameters") }[2];
	}

	$self->log->debug("tags path='$path' value='$value'");
	if ( $path eq 'name' and $value ) {
		return $self->_list_modules_with_tag($value);
	} elsif ( $path eq 'name_popup' ) {
		return $self->_list_modules_with_tag( $value, 'popup/' );
	} elsif ( $path eq 'user' and $value ) {
		my $tags = CPAN::Forum::DB::Tags->get_tags_of_user($value);
		return $self->_list_tags( $tags, { user_name => $value } );
	} else {
		my $tags = CPAN::Forum::DB::Tags->get_all_tags();
		return $self->_list_tags($tags);
	}
}

sub _list_tags {
	my ( $self, $tags, $params ) = @_;

		#loop_context_vars => 1,
		#global_vars       => 1,

	my $tag_count = 0;

	# maximize tag size to 24
	foreach my $t (@$tags) {
		#$tag_count += $t->{total};
		$t->{total} = 24 if $t->{total} > 24;
	}

	my %params = (
		tags => $tags,
	);

	#$t->param(tag_count => $tag_count);
	return $self->tt_process('pages/tags.tt', \%params);
}

sub _list_modules_with_tag {
	my ( $self, $value, $type ) = @_;
	$type ||= '';

	my $t = $self->load_tmpl(
		"${type}modules_with_tags.tmpl",
		loop_context_vars => 1,
		global_vars       => 1,
	);
	my $modules = CPAN::Forum::DB::Tags->get_modules_with_tag($value);
	$t->param( tag     => $value );
	$t->param( modules => $modules );

	my $referer = $ENV{HTTP_REFERER} || '';
	$referer =~ s{^(https?://[^/]+).*}{$1};

	#$t->param(referer => "$referer/dist");
	return $t->output;
}

1;


