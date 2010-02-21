package CPAN::Forum::RM::Threads;
use strict;
use warnings;

our $VERSION = '0.20';

use CPAN::Forum::DB::Posts ();
use CPAN::Forum::Tools ();

=head2 threads

Show all the posts of a single thread.

/threads/NNN

=cut

sub threads {
	my $self = shift;

	my $q = $self->query;

	my $id = $q->param("id");
	$id = ${ $self->param("path_parameters") }[0] if ${ $self->param("path_parameters") }[0];

	my $posts = CPAN::Forum::DB::Posts->posts_in_thread($id);
	if ( not @$posts ) {
		return $self->internal_error(
			"in request",
		);
	}

	# fill in the responses
	foreach my $p (@$posts) {
		$p->{responses} = [];
		foreach my $response (@$posts) {
			if ( $response->{parent} and $response->{parent} eq $p->{id} ) {
				push @{ $p->{responses} }, { id => $response->{id} };
			}
		}
	}

	my @posts_html;
	foreach my $p (@$posts) {
		push @posts_html, CPAN::Forum::Tools::format_post($p);
	}
	my %params = (
		posts => \@posts_html,
	);

	# (my $dashgroup = $posts[0]->gid) =~ s/::/-/g;
	$params{group} = $posts->[0]->{group_name};

	# $params{dashgroup} = $dashgroup;
	$params{title} = CPAN::Forum::Tools::_subject_escape( $posts->[0]->{subject} );

	return $self->tt_process('pages/threads.tt', \%params);
}

1;

