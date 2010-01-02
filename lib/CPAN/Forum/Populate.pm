package CPAN::Forum::Populate;

use Moose;

use CPAN::Mini     ();
use File::HomeDir  ();
use File::Path     qw(rmtree mkpath);
use File::Temp     qw(tempdir);

=head1 NAME

CPAN::Forum::Populate - populate the database by date from CPAN and other sources

=head1 SYNOPSIS

  my $p = CPAN::Forum::Populate->new(\%opts);
  
  %opts can contain
     mirror => 

  $p->run;

 
  $p->mirror_cpan();

  # tell what kind of processing to do
  $p->add_generate_html;
  $p->add_process_yaml;

  # start the processing on some of the file
  $p->process_all_files;
  $p->process_new_files;
  $p->process_file('path');
  
  $p->run;


=head1 DESCRIPTION

=cut

has 'mirror'      => (is => 'ro');
has 'dir'         => (is => 'rw');
has 'all_modules' => (is => 'rw');

=pod

=head2 mirror_cpan

Should be able to mirror a small subsection using CPAN::Mini or a full CPAN::Mini or a full CPAN mirror.

=cut

sub mirror_cpan {
	my ($self) = @_;

	if ($self->mirror) {
		die 'CPAN mirror not yet implemented' if $self->mirror eq 'cpan';
	}

	debug("Get CPAN");
	my $cpan = 'http://cpan.hexten.net/';
	my $cpan_dir = $self->cpan_dir;
	my $verbose = 0;
	my $force   = 1;

	my @filter;
	if ($self->mirror ne 'mini') {
		# comment out so won't delete mirror accidentally
		open my $fh, '<', $self->mirror or die "Could not open " . $self->mirror . " $!";
		my @modules = <$fh>; # TODO check formatting
		chomp @modules;
		close $fh;
		$self->all_modules(\@modules);
		@filter = (path_filters => [ sub { $self->filter(@_) } ]);
	}
	CPAN::Mini->update_mirror(
		remote       => $cpan,
		local        => $cpan_dir,
		trace        => $verbose,
		force        => $force,
		@filter,
	);

	return;
}
{
	my %modules;
	my %seen;

	sub filter {
		my ($self, $path) = @_;

		return $seen{$path} if exists $seen{$path};

		if (not %modules) {
			foreach my $name (@{ $self->all_modules }) {
				$name =~ s/::/-/g;
				$modules{$name} = 1;
			}
		}
		foreach my $module (keys %modules) {
			if ($path =~ m{/$module-v?\d}) { # Damian use a v prefix in the module name
				print "Mirror: $path\n";
				return $seen{$path} = 0;
			}
		}
		#die Dumper \%modules;
		#warn "@_\n";
		return $seen{$path} = 1;
	}
}



=pod

=head2 run

=cut

sub run {
	my ($self) = @_;

	$self->setup;
	$self->mirror_cpan;

	return;
}

sub setup {
	my ($self) = @_;

	# TODO allow --dir command line flag?
	if (not $self->dir) {
		my $home    = File::HomeDir->my_home;
		$self->dir("$home/.cpanforum");
	}
	my $src = $self->dir . '/src';
	mkpath($src) if not -e $src;
	debug("directory: " . $self->dir);

	return;
}

sub cpan_dir { return $_[0]->dir . '/cpan_mirror';  }

sub debug {
	print "@_\n";
}

=head1

=head1 LICENSE

Copyright 2004-2010, Gabor Szabo (gabor@pti.co.il)
 
This software is free. It is licensed under the same terms as Perl itself.

=cut



1;