package CPAN::Forum::Markup;
use strict;
use warnings;

use CGI qw();
use Parse::RecDescent;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
	
	$self->{grammar} = q {
	entry      : chunk(s) eodata                  { $item[1] }
	chunk      : marked_html | marked_code        { $item[1] }

	marked_html: html(s)                          { qq(<div class="text">) . join("", @{$item[1]}) . qq(</div>); }
	html       : text                             { $item[1] } 
	           | block                            { $item[1] }
			   | inline                           { $item[1] }
	block      : open_p inline(s) close_p         { "<p>" . join("", @{$item[2]}) . "</p>" } 


	inline     : text                             { $item[1] }
	           | open_b text close_b              { join "", @item[1..$#item] }
	           | open_i text close_i              { join "", @item[1..$#item] }
			   | br                               { $item[1] }
			   | open_a text close_a              { join "", @item[1..$#item] }

	br         : m{<br( /)?>}i                    { "<br />" }
	open_p     : m{<p>}i                          { "<p>"  }
	close_p    : m{</p>}i                         { "</p>" }
	open_b     : m{<b>}i                          { "<b>"  }
	close_b    : m{</b>}i                         { "</b>" }
	open_i     : m{<i>}i                          { "<i>"  }
	close_i    : m{</i>}i                         { "</i>" }

	open_a      : open_a_href urlx open_a_gt      { qq(<a href="$item[2]">) }
	open_a_href : m{<a href=}i
	urlx        : quote url quote                 {$item[2]}
				| url                             {$item[1]}
	url         : http
	            | mailto
	http        : m{http://[^">]+}i               { lc $item[1]  }
	mailto      : m{mailto:[^">]+}i               { lc $item[1]  }   
	open_a_gt   : m{>}     
	quote       : m{"}

	close_a    : m{</a>}i                         { "</a>" }


	text       : m{[\r\t\n -;=?-~]+}              {$item[1] }

	marked_code: open_code code close_code        { join("", @item[1..$#item]) }
	open_code  : m{<code>}                        { qq(<div class="code">) }
	close_code : m{</code>}                       { qq(</div>) }
	code       : m{[\r\t\n -~]+?(?=</code>)}      { CPAN::Forum::Markup::split_rows(join "", @item[1..$#item]) }

	eodata     : m{^\Z}
	};

	$Parse::RecDescent::skip = '';

	return $self;
}



# takes a string
# makes sure every line is max N characters long
sub split_rows {
	my ($text, $N) = @_;
	$N ||= 100;
	my $NEXTMARK = '<span class="nextmark">+</span>';

	my @text = split /\n/, $text;
	my @new;
	while (@text) {
		my $row = shift @text;
		if (length $row <= $N) {
			push @new, CGI::escapeHTML($row);
			next;
		}
		push @new, CGI::escapeHTML(substr($row, 0, $N-1, ""));
		while (length $row > $N) {
			push @new,  $NEXTMARK . CGI::escapeHTML(substr($row, 0, $N-2, ""));
		}
		push @new, $NEXTMARK . CGI::escapeHTML($row);
		
	}
	return join "\n", @new;
}

sub parser {
	my ($self) = @_;
	return Parse::RecDescent->new($self->{grammar});
}

sub posting_process {
	my ($self, $text) = @_;

	my $parser = $self->parser;
	if (not $parser) {
		warn "Bad Grammar\n";
		return;
	}
	my $out = $parser->entry($text);
	return if not defined $out;
	return join("",@$out);
}


=head1 NAME

CPAN::Forum::Markup - Markup definitions and processing for CPAN::Forum

=head1 SYNOPSIS

	my $markup = CPAN::Forum::Markup->new();
	my $result = $markup->posting_process($new_text) ;

=head1 DESCRIPTION

Based on Parse::RecDescent, this module provide a method to check if a give
piece of text is a valid post. It returns the text in the format it could be
sent to the user or returns undef if the text is invalid.

=cut


1;

