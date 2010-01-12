package CPAN::Forum::Daemon;
use strict;
use warnings;
use 5.008;

use Moose;
use CPAN::Forum::DBI;
use CPAN::Forum::DB::Posts;


has 'idle'  => ( is => 'ro' );

# we want to have the 'new' of Moose but also inherit from the Notify class
# at least for now
extends 'CPAN::Forum::RM::Notify', 'Moose::Object';

sub run {
	my $self = shift;
	CPAN::Forum::DBI->myinit();
	
	while(1) {
		$self->notification;

		last if not $self->idle;
		sleep $self->idle;
	}
}


sub notification {
	my $self = shift;
	my $posts = CPAN::Forum::DB::Posts->to_notify();
	foreach my $post_id (@$posts) {
#		print STDERR "# post id to be notified $post_id\n";
		$self->notify($post_id);
		CPAN::Forum::DB::Posts->set_notified($post_id);
	}

	return;
}


1;