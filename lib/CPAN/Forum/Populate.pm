package CPAN::Forum::Populate;

use Moose;

use CPAN::Mini        ();
use File::Basename    qw(basename dirname);
use File::Find::Rule  ();
use File::HomeDir     ();
use File::Path        qw(rmtree mkpath);
use File::Temp        qw(tempdir);

use CPAN::Forum::Pod;

=head1 NAME

CPAN::Forum::Populate - populate the database by date from CPAN and other sources

=head1 SYNOPSIS

  my $p = CPAN::Forum::Populate->new(\%opts);
  
  %opts can contain
     mirror => 

  $p->run;

 
  $p->mirror_cpan();

  # tell what kind of processing to do

  # start the processing on some of the file
  $p->process;
  

=head1 DESCRIPTION

=cut

has 'mirror'      => (is => 'ro');
has 'process'     => (is => 'ro');
has 'html'        => (is => 'ro');
has 'yaml'        => (is => 'ro');
has 'ppi'         => (is => 'ro');


has 'dir'         => (is => 'rw');
has 'cpan'        => (is => 'rw');
has 'all_modules' => (is => 'rw');
has 'file'        => (is => 'rw');
has 'dist'        => (is => 'rw');
has 'version'     => (is => 'rw');
has 'source_path' => (is => 'rw');
has 'html_path'   => (is => 'rw');

=pod

=head2 mirror_cpan

Should be able to mirror a small subsection using CPAN::Mini or a full CPAN::Mini or a full CPAN mirror.

=cut

sub mirror_cpan {
	my ($self) = @_;

	return if not $self->mirror;
	# TODO implement full CPAN mirror (using rsync?)
	die "Full CPAN mirror not yet implemented, use mini of filename\n" if $self->mirror eq 'cpan'; 

	debug("Get CPAN");
	my $cpan = $self->cpan;
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

=head2 process

=cut

sub process_files {
	my ($self) = @_;
	return if not $self->process;
	
	die '--process all   not yet implemented' if $self->process eq 'all';
	die '--process new   not yet implemented' if $self->process eq 'new';


	$self->file($self->process);
	$self->unzip_file;
	$self->generate_html;
	$self->update_meta_data;
	$self->process_ppi;

	return;
}


sub unzip_file {
	my ($self) = @_;

	my $src = $self->source_dir;
	mkpath($src) if not -e $src;

	my $file = $self->file;
	# file look like this:
	# R/RJ/RJBS/CPAN-Mini-0.576.tar.gz
	# A/AA/AADLER/Games-LogicPuzzle-0.20.zip
	if ($file !~ m{^(\w)/(\1\w)/(\2\w+)/([\w-]+)-([\d.]+)\.(tar\.gz|zip)$}) {
		die "File '$file' is not a recognized format";
	}
	my $pauseid  = $3;
	my $package  = $4;
	my $version  = $5;
	debug("PAUSE '$pauseid' package  '$package' version '$version'");
	my $filename = basename($file);
	my $root     = '';
	my $path     = dirname($file);
	$self->dist($package);
	$self->version($version);
	
	my $target_parent_dir = "$src/$path";
	mkpath($target_parent_dir);

	$self->source_path("$target_parent_dir/$package-$version");
	my $dir = $self->dir;
	my $html_parent_dir = "$dir/html/$path";
	$self->html_path("$html_parent_dir/$package-$version");

	return if -e $self->source_path;

	# TODO: having more control with Archive::Zip or similar module?
	chdir $target_parent_dir or die;
	my $cpan_dir = $self->cpan_dir;
	# TODO unzip within a temp directory in case the zipped file does not have a main directory in it?
	if (substr($file, -7) eq '.tar.gz') {
		_system("tar xzf $cpan_dir/authors/id/$file");
	} elsif (substr($file, -4) eq '.zip') {
		_system("unzip $cpan_dir/authors/id/$file");
	} else {
		warn "unrecognized file '$file'";
	}

	return;
}


sub generate_html {
	my ($self) = @_;

	return if not $self->html;


	my $pod = CPAN::Forum::Pod->new;
	my $html;
	$pod->output_string(\$html);

	my $src  = $self->source_path;
	my $dest = $self->html_path;
	debug("Generate HTML for $src");
	die "No source path" if not $src;
	die "Source path '$src' does not exist'" if not -d $src;
	# TODO, deal with packages where the main module is not in the lib/ directory (e.g. id/A/AA/AADLER/Games-LogicPuzzle-0.20.zip )
	foreach my $file (File::Find::Rule->file->name('*.pm', '*.pod')->relative->in("$src/lib")) {
		$html = '';
		debug("   POD processing $file");
		$pod->parse_file("$src/lib/$file");
		if ($pod->content_seen) {
			$file =~ s/\.\w+$/.html/;
			my $outfile = "$dest/lib/$file";
			mkpath(dirname($outfile));
			if (open my $out, '>', $outfile) {
				print $out $html;
			} else {
				warn "Could not open '$outfile' for writing $!";
			}
		}
		
	}

	# create symbolic link

	my $dir = $self->dir;
	mkpath("$dir/dist/");
	my $dist = $self->dist;
	unlink "$dir/dist/$dist" or die $!;
	debug( "Unlink $dir/dist/$dist" );
	_system("ln -s $dest $dir/dist/$dist");

	return;
}


sub update_meta_data {
	my ($self) = @_;
	return if not $self->meta;
	return;
}

sub process_ppi {
	my ($self) = @_;
	return if not $self->ppi;
	return;
}

=pod

=head2 run

=cut

sub run {
	my ($self) = @_;

	$self->setup;
	$self->mirror_cpan;
	$self->process_files;

	return;
}

sub setup {
	my ($self) = @_;

	if (not $self->dir) {
		my $home    = File::HomeDir->my_home;
		$self->dir("$home/.cpanforum");
	}
	debug("directory: " . $self->dir);

	# TODO allow --cpan command line flag?
	if (not $self->cpan) {
		$self->cpan('http://cpan.hexten.net/')
	}

	return;
}

sub cpan_dir   { return $_[0]->dir . '/cpan_mirror';  }
sub source_dir { return $_[0]->dir . '/src';  }

sub _system {
	my ($cmd) = @_;
	debug($cmd);
	system($cmd);
	return;
}

sub debug {
	print "@_\n";
}

=head1

=head1 LICENSE

Copyright 2004-2010, Gabor Szabo (gabor@pti.co.il)
 
This software is free. It is licensed under the same terms as Perl itself.

=cut



1;