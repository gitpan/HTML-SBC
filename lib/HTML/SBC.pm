package HTML::SBC;

=head1 NAME

HTML::SBC - simple blog code for valid (X)HTML

=head1 VERSION

Version 0.13

=cut

our $VERSION = '0.13';

use warnings;
use strict;
use Carp;
use Scalar::Util    qw( blessed );
use Exporter;

# "vintage" interface
my @vintage = qw(
    sbc_translate sbc_translate_inline sbc_quote sbc_description
);
use base qw( Exporter );
our @EXPORT_OK = (@vintage, );
our %EXPORT_TAGS = (all => \@EXPORT_OK, vintage => \@vintage);

=head1 SYNOPSIS

    use HTML::SBC;
    my $translator  = HTML::SBC->new();
    my $html        = $translator->sbc($text);

or with vintage interface:
    
    use HTML::SBC qw(sbc_translate);
    my $html = sbc_translate($text);

=head1 DESCRIPTION

I<Simple Blog Code> is a simple markup language. You can use it for guest
books, blogs, wikis, boards and various other web applications. It produces
valid and semantic (X)HTML from input and is patterned on that tiny usenet
markups like *B<bold>* and _underline_. See L<language description|/Language>
for details.

HTML::SBC tries to give useful error messages and guess the right translation
even with invalid input. It will B<always> produce valid (X)HTML.

=head2 OOP Interface

HTML::SBC now (since 0.10) uses an OO interface, but the old interface is still
available. See L</Vintage interface> for details.

=head3 Constructor

=over 4

=item new

    my $translator = HTML::SBC->new()

creates a translator with english language for error messages. Additionally,
you can set initial values for all attributes, e. g.:

    my $translator = HTML::SBC->new({
        language            => 'german',
        image_support       => 1,
        error_callback      => sub
                { print "<li>$_[0]</li>\n"; },
        linkcheck_callback  => sub
                { return $_[0] =~ m{archive}; },
        imgcheck_callback   => sub
                { return $_[0] =~ m{naked\d{4}\,jpg}; },
    });

For the meaning of the attributes, see the accessor documentations below.
B<Note:> the arguments for C<new> are passed in a hashref.

=cut

my @lang = qw( english german );

{
my %defaults = (
    language            => $lang[0],
    image_support       => undef,
    error_callback      => undef,
    linkcheck_callback  => undef,
    imgcheck_callback   => undef,
);

sub new {
    my ($class, $args) = @_;
    $args ||= {};
    croak 'Arguments expected as hash ref' if ref $args ne 'HASH';
    my $self = bless { %defaults, %$args }, $class;
    $self->_init;
    return $self;
}
} # end of lexical %defaults

sub _init {
    my ($self) = @_;
    $self->{text}       =  '';
    $self->{result}     =  '';
    $self->{attribute}  =  '';
    $self->{errors}     = [ ];
    $self->{istack}     = { };
    $self->{qstack}     =   0;
    $self->{line}       =   0;
}

# private error reporting sub
{
my %error = (
    no_quote_end => {
        $lang[0]    => q(No quote end tag ']'),
        $lang[1]    => q(Kein Zitatende-Zeichen ']'),
    },
    no_emphasis_end => {
        $lang[0]    => q(No emphasis end tag '*'),
        $lang[1]    => q(Kein Betonungs-Endezeichen '*'),
    },
    no_strong_end => {
        $lang[0]    => q(No strong end tag '_'),
        $lang[1]    => q(Kein Hervorhebungs-Endezeichen '_'),
    },
    no_hyperlink_end => {
        $lang[0]    => q(No hyperlink end tag '>'),
        $lang[1]    => q(Kein Hyperlink-Endezeichen '>'),
    },
    no_image_end => {
        $lang[0]    => q(No image end tag '}'),
        $lang[1]    => q(Kein Bild-Endezeichen '}'),
    },
    forbidden_url => {
        $lang[0]    => q(Forbidden URL),
        $lang[1]    => q(Verbotener URL),
    },
    unknown_token => {
        $lang[0]    => q(Unknown token),
        $lang[1]    => q(Unbekanntes Zeichen),
    },
    line => {
        $lang[0]    => q(around logical line),
        $lang[1]    => q(um logische Zeile),
    },
);

sub _error {
    my ($self, $error, $arg) = @_;
    my $string = join ' ', (
        $error{$error}{$self->language()},
        ($arg) x ! ! $arg, # additional information to this error message
        $error{line}{$self->language()},
        $self->{line},
    );
    push @{ $self->{errors} }, $string;
    $self->_error_callback($string);
}
} # end of lexical %error

sub _error_callback {
    my ($self, @args) = @_;
    $self->{error_callback}->(@args) if defined $self->{error_callback};
}

sub _linkcheck_callback {
    my ($self, @args) = @_;
    if (defined $self->{linkcheck_callback}) {
        return $self->{linkcheck_callback}->(@args);
    }
    return 1; # all URIs are valid by default
}

sub _imgcheck_callback {
    my ($self, @args) = @_;
    if (defined $self->{imgcheck_callback}) {
        return $self->{imgcheck_callback}->(@args);
    }
    return 1; # all IMG URIs are valid by default
}
    
# basic html things
sub _pre {
    my ($self) = @_;
    $self->{text} =~ s/&/&amp;/g;
    $self->{text} =~ s/\\</&lt;/g;
    $self->{text} =~ s/\\>/&gt;/g;
    $self->{text} =~ s/"/&quot;/g;
    $self->{text} =~ s/[\t ]+/ /g;
}

# make clean...
sub _post {
    my ($self) = @_;
    $self->{result} =~ s/\\([*_<>{}\[\]#\\])/$1/g;
}

# tokenizer
{
my %token = (
    EMPHASIS        =>  qr{^\*},
    STRONG          =>  qr{^_},
    HYPERLINK_START =>  qr{^<(https?://[^ >\n]+) *},
    HYPERLINK_END   =>  qr{^>},
    IMAGE_START     =>  qr|^{(https?://[^ }\n]+) *|,
    IMAGE_END       =>  qr|^}|,
    QUOTE_START     =>  qr{^\n+\[\n?},
    QUOTE_END       =>  qr{^\] *\n+},
    QUOTE_END_CITE  =>  qr{^\] *},
    UL_BULLET       =>  qr{^\n+- *},
    OL_BULLET       =>  qr{^\n+# *},
    LINEBREAK       =>  qr{^\n+},
    PLAIN           =>  qr{^((?:[^*_<>\{\}\[\]#\\\n]+|\\[*_<>\{\}\[\]#\\\n])*)},
);

sub _literal {
    my ($self, $token, $replacement) = @_;
    $replacement = '' unless defined $replacement;
    my $regex = $token{$token};

    my $success = $self->{text} =~ s/$regex/$replacement/;
    $self->{attribute} = $1 || undef;
    return $success;
}
} # end of lexical %token

# parser...
sub _sbc {
    my ($self) = @_;
    my $sbc = '';
    while (my $block = $self->_block()) {
        $sbc .= $block;
    }
    return $sbc;
}

sub _block {
    my ($self) = @_;
    return( $self->_quote()
        or  $self->_ulist()
        or  $self->_olist()
        or  $self->_paragraph()
    );
}

sub _quote {
    my ($self) = @_;
    $self->_literal('QUOTE_START', "\n") or return;

    $self->{line}++;
    $self->{qstack}++;
    my $quote = $self->_sbc();
    $self->{qstack}--;

    if ($self->_literal('QUOTE_END', "\n")) {
        return qq(<div class="quote">)
            .  qq(<blockquote>\n$quote</blockquote></div>\n);
    }
    elsif ($self->_literal('QUOTE_END_CITE')) {
        my $cite = $self->_inline();
        return qq(<div class="quote"><cite>$cite</cite>)
            .  qq(<blockquote>\n$quote</blockquote></div>\n);
    }
    else {
        $self->_error('no_quote_end');
        return qq(<div class="quote">)
            .  qq(<blockquote>\n$quote</blockquote></div>\n);
    }
}

sub _ulist {
    my ($self) = @_;
    my $ulist = '';
    while (my $ulitem = $self->_ulitem()) {
        $ulist .= $ulitem;
    }
    return if $ulist eq '';
    return qq(<ul>\n$ulist</ul>\n);
}

sub _ulitem {
    my ($self) = @_;
    $self->_literal('UL_BULLET') or return;
    $self->{line}++;
    my $ulitem = $self->_inline();
    return qq(\t<li>$ulitem</li>\n);
}

sub _olist {
    my ($self) = @_;
    my $olist = '';
    while (my $olitem = $self->_olitem()) {
        $olist .= $olitem;
    }
    return if $olist eq '';
    return qq(<ol>\n$olist</ol>\n);
}

sub _olitem {
    my ($self) = @_;
    $self->_literal('OL_BULLET') or return;
    $self->{line}++;
    my $olitem = $self->_inline();
    return qq(\t<li>$olitem</li>\n);
}

sub _paragraph {
    my ($self) = @_;
    $self->_literal('LINEBREAK') or return;
    $self->{line}++;
    my $paragraph = $self->_inline();

    unless ($self->{qstack} or $self->_literal('LINEBREAK', "\n")) {
        $self->{line}--;
        return;
    }
    if ($paragraph =~ /^\s*$/) {
        return "\n";
    }
    else {
        return qq(<p>$paragraph</p>\n);
    }
}

sub _inline {
    my ($self) = @_;
    my $inline = '';

    while (1) { # use Acme::speeed to accelerate this!
        if (not $self->{istack}{EMPHASIS} and
            defined(my $emphasis = $self->_emphasis())) {
                $inline .= $emphasis; next;
        }
        elsif (not $self->{istack}{STRONG} and
               defined(my $strong = $self->_strong())) {
                $inline .= $strong; next;
        }
        elsif (not $self->{istack}{HYPERLINK} and
               defined(my $hyperlink = $self->_hyperlink())) {
                $inline .= $hyperlink; next;
        }
        elsif ($self->image_support() and
               defined(my $image = $self->_image())) {
                $inline .= $image; next;
        }
        elsif (defined(my $plain = $self->_plain())) {
                $inline .= $plain; next;
        }
        else {
                last;
        }
    }

    return $inline;
}

sub _emphasis {
    my ($self) = @_;
    $self->_literal('EMPHASIS') or return;
    $self->{istack}{EMPHASIS}++;
    my $emphasis = $self->_inline();
    $self->_literal('EMPHASIS') or $self->_error('no_emphasis_end');
    $self->{istack}{EMPHASIS}--;
    return '' if $emphasis eq '';
    return qq(<em>$emphasis</em>);
}

sub _strong {
    my ($self) = @_;
    $self->_literal('STRONG') or return;
    $self->{istack}{STRONG}++;
    my $strong = $self->_inline();
    $self->_literal('STRONG') or $self->_error('no_strong_end');
    $self->{istack}{STRONG}--;
    return '' if $strong eq '';
    return qq(<strong>$strong</strong>);
}

sub _hyperlink {
    my ($self) = @_;
    $self->_literal('HYPERLINK_START') or return;
    $self->{istack}{HYPERLINK}++;
    my $url = $self->{attribute};
    my $link = $self->_inline();
    $link = $url if $link =~ /^ *$/;
    $self->_literal('HYPERLINK_END') or $self->_error('no_hyperlink_end');
    $self->{istack}{HYPERLINK}--;
    if ($self->_linkcheck_callback($url)) {
        return qq(<a href="$url">$link</a>);
    }
    else {
        $self->_error('forbidden_url', $url);
        return $link;
    }
}

sub _image {
    my ($self) = @_;
    $self->_literal('IMAGE_START') or return;
    my $url = $self->{attribute};
    my $alt = '';
    while (my $plain = $self->_plain()) {
        $alt .= $plain;
    }
    $self->_literal('IMAGE_END') or $self->_error('no_image_end');
    if ($self->_imgcheck_callback($url)) {
        return qq(<img src="$url" alt="$alt">);
    }
    else {
        $self->_error('forbidden_url', $url);
        return '';
    }
}

sub _plain {
    my ($self) = @_;
    $self->_literal('PLAIN') and return $self->{attribute};
}

=back

=head3 Accessor methods

=over 4

=item language

Accessor method for the C<language> field. It defines the language of your error
messages. All accessors are both setter and getter:

    $language = $translator->language();
    $translator->language($new_language);

Valid languages: 'english' (default), 'german'.

=item image_support

Accessor method for the C<image_support> field. It defines whether image code is
parsed or not. Image markup is translated if and only if this field has a true
value, so for this field all values are valid.

=item error_callback

Accessor method for the C<error_callback> field. The C<error_callback> callback
is called on every error that occurs while parsing your SBC input. It gets the
error message as first argument. Valid values are: undef, coderefs.

=item linkcheck_callback

Accessor method for the C<linkcheck_callback> field. The <linkcheck_callback>
callback is called if there is hyperlink markup in your SBC input. It gets the
URL as first argument and has to return a true value if that URL is considered
valid, false otherwise. Valid values are: undef, coderefs.

=item imgcheck_callback

Accessor method for the C<imgcheck_callback> field. The <imgcheck_callback>
callback is called if there is image markup in your SBC input. It gets the URL
as first argument and has to return a true value if that URL is considered
valid, false otherwise. Valid values are: undef, coderefs.

=cut

{
# accessor checks
my %checks = (
    language            => sub { my ($l) = @_;
        scalar grep { $_ eq $l } @lang
    },
    image_support       => sub {
        1;
    },
    error_callback      => sub {
        ! blessed($_[0]) && ref $_[0] eq 'CODE' || ! defined $_[0] 
    },
    linkcheck_callback  => sub {
        ! blessed($_[0]) && ref $_[0] eq 'CODE' || ! defined $_[0]
    },
    imgcheck_callback   => sub {
        ! blessed($_[0]) && ref $_[0] eq 'CODE' || ! defined $_[0]
    },
);

# accessor generation
while (my ($field, $valid) = each %checks) {
    no strict 'refs';
    *$field = sub {
        my $self = shift;
        if (@_) {
            my $new = shift;
            if (defined $valid and not $valid->($new)) {
                croak "Invalid value for $field: $new";
            }
            $self->{$field} = $new;
        }
        return $self->{$field};
    };
}
} # end of lexical %check

=back

=head3 Translation methods

=over 4

=item sbc

    my $html = $translator->sbc($text);

Returns some valid HTML block elements which represent the given SBC C<$text>.

=cut

sub sbc {
    my ($self, $text) = @_;
    return undef unless defined $text;
    return '' if $text =~ /^\s*$/;
    $self->_init();
    $self->{text} = $text;
    $self->_pre();
    $self->{text} = "\n$self->{text}\n";
    $self->{text} =~ s/[\r\n]+/\n/g;
    $self->{result} = $self->_sbc();
    $self->_post();
    $self->{result} =~ s/\\\n/<br>/g;
    $self->_error('unknown_token') unless $self->{text} =~ /^\n*$/;
    return $self->{result};
}

=item sbc_inline

    my $line = $translator->sbc_inline($text);

Returns some valid HTML inline content which represents the given SBC C<$text>.
C<$text> may only contain inline SBC markup.

=cut

sub sbc_inline {
    my ($self, $text) = @_;
    return undef unless defined $text;
    return '' if $text =~ /^\s*$/;
    $self->_init();
    $self->{text} = $text;
    $self->_pre();
    $self->{text} =~ s/[\r\n]+/ /g;
    $self->{result} = $self->_inline();
    $self->_post();
    $self->_error('unknown_token') unless $self->{text} =~ /^\n*$/;
    return $self->{result};
}

=back

=head3 Error handling methods

After translation you can look for errors in your SBC input:

=over 4

=item errors

    my @errors = $translator->errors();

returns a list of warnings/errors in the chosen language.

=cut

sub errors {
    my ($self) = @_;
    return @{$self->{errors}};
}

=item next_error

    while (my $error = $translator->next_error()) {
        do_something_with($error);
    }

Implements an iterator interface to your error messages. It will return the next
error message or undef if there's nothing left.

=cut

sub next_error {
    my ($self) = @_;
    return shift @{ $self->{errors} };
}

=back

Remember the possibility to use your own error callback method.

=head3 Class methods

There are some SBC tools implemented as class methods.

=over 4

=item quote

    my $reply = HTML::SBC->quote($original);

If you have some text in simple blog code C<$original> and you want it to be
sbc-quoted (e. g. for reply functionality in boards). You can add the author's
name as second argument:

    my $reply = HTML::SBC->quote($original, $author);

=cut

sub quote {
    my ($class, $sbc, $cite) = @_;
    $cite = '' unless defined $cite;
    return qq([\n$sbc\n]$cite\n);
}

=item description

    my $description = HTML::SBC->description('german');

If you want some newbies to use SBC, just show them our SBC language
description in your favourite language (english is default).

=cut

{
my %desc = (
    $lang[0] => <<DESC_EN,
Simple Blog Code is easy. Paragraphs are directly translated in paragraphs. Codes in paragraphs:
- _\\*foo\\*_ emphasis: *foo*
- _\\_bar\\__ strong emphasis: _bar_
- _\\<http://www.example.org\\>_ hyperlinks with its URL as text: <http://www.example.org>
- _\\<http://www.example.org baz\\>_ hyperlinks with *baz* as text: <http://www.example.org baz>
- _\\{http://www.memowe.de/pix/sbc.jpg\\}_ images without alternative text (*may be disabled*).
- _\\{http://www.memowe.de/pix/sbc.jpg SBC\\}_ images with alternative text *SBC* (*may be disabled*).
You can use unordered lists:
_- one thing\\
- another thing_
will be
- one thing
- another thing
Or ordered lists:
_\\# first\\
\\# second_
will be
# first
# second
In lists you can use the codes from paragraphs. With square brackets one can mark up quotes. A _\\[Quote\\]_ looks like this:
[Quote]
Or you can add the quote's author after the closing bracket: _\\[Quote\\] Author_:
[Quote] Author
A quote may contain paragraphs, lists and quotes. Author information may contain all codes from paragraphs. Special characters from SBC have to be *escaped* with a backslash: _\\\\\\*_, _\\\\\\__, ...; even the backslash itself: _\\\\\\\\_.
DESC_EN
    $lang[1] => <<DESC_DE,
Simple Blog Code ist einfach. Absätze werden direkt in Absätze übersetzt. Codes in Absätzen:
- _\\*foo\\*_ Betonte Texte: *foo*
- _\\_bar\\__ Hervorgehobene Texte: _bar_
- _\\<http://www.example.org\\>_ Hyperlinks mit Adresse als Text: <http://www.example.org>
- _\\<http://www.example.org baz\\>_ Hyperlinks mit *baz* als Text: <http://www.example.org baz>
- _\\{http://www.memowe.de/pix/sbc.jpg\\}_ Bilder ohne alternativen Text (*möglicherweise deaktiviert*).
- _\\{http://www.memowe.de/pix/sbc.jpg SBC\\}_ Bilder mit alternativem Text *SBC* (*möglicherweise deaktiviert*).
Statt Absätzen kann man ungeordnete Listen verwenden:
_- Einerseits\\
- Andererseits_
wird zu
- Einerseits
- Andererseits
Oder geordnete Listen:
_\\# Erstens\\
\\# Zweitens_
wird zu
# Erstens
# Zweitens
Innerhalb von Listen können die Codes von Absätzen verwendet werden. Mit eckigen Klammern kann man Zitate auszeichnen. Ein _\\[Zitat\\]_ sieht so aus:
[Zitat]
Man kann auch die Quelle des Zitats angeben, nämlich hinter der schließenden eckigen Klammer: _\\[Zitat\\]_ Quelle
[Zitat] Quelle
Ein Zitat kann wieder Absätze, Listen und Zitate enthalten, in Quellenangaben können alle Codes verwendet werden, die auch Absätze kennen. Sonderzeichen von SBC müssen mit einem Backslash codiert werden: _\\\\\\*_, _\\\\\\__, usw. und auch der Backslash selbst: _\\\\\\\\_.
DESC_DE
);

sub description {
    my ($class, $lang) = @_;
    $lang = $lang[0] unless defined $lang;
    croak "Unknown language '$lang'" unless grep { $lang eq $_ } @lang;
    return scalar sbc_translate($desc{$lang});
}
} # end of lexical %desc

=back

=head2 Vintage interface

For backward compatibility, HTML::SBC implements its vintage non-OO interface
(versions < 0.10) so you can use newer versions of HTML::SBC without any changes
in your source code, for example:

    use HTML::SBC qw( sbc_translate );
    HTML::SBC::german();
    my ($html, $errors) = sbc_translate($text);
    print "$_\n" for @$errors;

To import this vintage interface,

    use HTML::SBC qw( sbc_translate sbc_description );

or import everything (except language getter):

    use HTML::SBC qw( :vintage );

=cut

{
my $static_transl; # for vintage interface

sub _static {
    unless (defined $static_transl) {
        $static_transl = HTML::SBC->new({
            image_support   => 0, # no image support in versions < 0.10
        });
    }
    return $static_transl;
}
} # end of lexical $static_transl

sub _static_lang {
    my $transl = _static();
    return $transl->language();
}

=over 4

=item english

C<HTML::SBC::english()> sets the language of your error messages to I<english>.

=item german

C<HTML::SBC::german()> sets the language of your error messages to I<german>.

=item sbc_translate

    my ($html, $errors) = sbc_translate($text);

C<sbc_translate()> returns the html output and an arrayref to your error
messages. To ignore the errors, just evaluate C<sbc_translate()> in scalar
context.

=item sbc_translate_inline

    my ($inline_html, $errors) = sbc_translate_inline($inline_text);

does the same with inline content (see C<sbc_inline>).

=item sbc_quote

    my $reply = sbc_quote($original);

If you have some text in simple blog code C<$original> and you want it to be
sbc-quoted (e. g. for reply functionality in boards), just use this. You can
add the author's name as second argument:

    my $reply = sbc_quote($original, $author);

=item sbc_description

    my $description = sbc_description();

If you want some newbies to use SBC, just show them our SBC language
description.

=cut

foreach my $lang (@lang) {
    no strict 'refs';
    *$lang = sub {
        my $static_obj = _static();
        $static_obj->language($lang);
    };
}

sub sbc_translate {
    my ($text) = @_;
    my $transl = _static();
    my $result = $transl->sbc($text);
    my @errors = $transl->errors();
    return wantarray ? ($result, \@errors) : $result;
}

sub sbc_translate_inline {
    my ($line) = @_;
    my $transl = _static();
    my $result = $transl->sbc_inline($line);
    my @errors = $transl->errors();
    return wantarray ? ($result, \@errors) : $result;
}

sub sbc_quote {
    my ($sbc, $cite) = @_;
    return HTML::SBC->quote($sbc, $cite);
}

sub sbc_description {
    return HTML::SBC->description(_static_lang());
}

=back

=head2 Language

I<Simple blog code> is a simple markup language. Paragraphs in input (text
between newlines) are translated in (X)HTML P elements. In paragraphs, some

=head3 inline elements

are allowed as follows:

=over 4

=item C<*emphasis*>

    <em>emphasis</em>

=item C<_strong emphasis_>

    <strong>strong emphasis</strong>

=item C<< <http://www.example.org/> >>

    <a href="http://www.example.org/">http://www.example.org/</a>

=item C<< <http://www.example.org/ hyperlink> >>

    <a href="http://www.example.org/">hyperlink</a>

=item C<< {http://www.example.org/foo.jpg} >> (optional, only in oo)

    <img src="http://www.example.org/foo.jpg" alt="">

=item C<< {http://www.example.org/foo.jpg image} >> (optional, only in oo)

    <img src="http://www.example.org/foo.jpg" alt="image">

=back

There are some elements on block level which don't have to be in paragraphs.

=head3 block level elements

=over 4

=item C<[nice quote]>

    <div class="quote">
        <blockquote>
            nice quote
        </blockquote>
    </div>

=item C<[another nice quote] author>

    <div class="qoute">
        <cite>author</cite>
        <blockquote>
            another nice quote
        </blockquote>
    </div>

=item C<- first\n- second\n- third\n>

    <ul>
        <li>first</li>
        <li>second</li>
        <li>third</li>
    </ul>

=item C<# first\n# second\n# third\n>

    <ol>
        <li>first</li>
        <li>second</li>
        <li>third</li>
    </ol>

=back

Block level elements have to be started in new lines. In quotes, you can use
block level elements, e. g.

    [
    \[...\] the three great virtues of a programmer:
    - laziness,
    - impatience and
    - hubris.
    ] Larry Wall

You'll get the nice quote from Larry with an inner list. You can see here, that
characters with a special meaning have to be escaped in SBC. You would use "\*"
to get an asterisk, for example.

=head1 AUTHOR

Mirko Westermeier, C<< <mail at memowe.de> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-html-sbc at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTML-SBC>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

I love feedback. :-)

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTML::SBC

=head1 ACKNOWLEDGEMENTS

Thanks to Florian Ragwitz (rafl) for many helpful comments and suggestions.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Mirko Westermeier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of HTML::SBC
