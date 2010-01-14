package CPAN::Forum::RM::Threads;
use strict;
use warnings;

=head2 threads

Show all the posts of a single thread.

/threads/NNN

=cut

sub threads {
	my $self = shift;

	my $q = $self->query;
	my $t = $self->load_tmpl(
		"threads.tmpl",
		loop_context_vars => 1,
	);

	my $id = $q->param("id");
	$id = ${ $self->query->param("path_parameters") }[0] if ${ $self->query->param("path_parameters") }[0];

	my $posts = CPAN::Forum::DB::Posts->posts_in_thread($id);
	if ( not @$posts ) {
		return $self->internal_error(
			"in request",
		);
	}
	$self->log->debug( Data::Dumper->Dump( [$posts], ['posts'] ) );

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
		push @posts_html, $self->_post($p);
	}
	$t->param( posts => \@posts_html );

	#   (my $dashgroup = $posts[0]->gid) =~ s/::/-/g;
	$t->param( group => $posts->[0]->{group_name} );

	#   $t->param(dashgroup => $dashgroup);
	$t->param( title => _subject_escape( $posts->[0]->{subject} ) );

	return $t->output;
}

1;

