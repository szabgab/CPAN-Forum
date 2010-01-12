package CPAN::Forum::Daemon;
use strict;
use warnings;
use 5.008;

use Moose;
use CPAN::Forum::DBI;

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
	my @posts = CPAN::Forum::DB::Posts->to_notify();
	foreach my $post_id (@posts) {
		warn "# id $post_id->[0]\n";
		$self->notify($post_id->[0]);
		CPAN::Forum::DB::Posts->set_notified($post_id->[0]);
	}

	return;
}


1;
