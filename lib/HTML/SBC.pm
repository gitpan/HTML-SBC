package HTML::SBC;
# Author: Mirko Westermeier <mail@memowe.de>
# see pod below

use strict;
use warnings;

use base qw(Exporter);
our @EXPORT_OK      = qw(
        sbc_translate
        sbc_translate_inline
        sbc_quote
        sbc_description
    );
our %EXPORT_TAGS    = (all => [ qw(
        sbc_translate
        sbc_translate_inline
        sbc_quote
        sbc_description
    ) ]);

our $VERSION = '0.08';

# private status variables
my ($text, $result, @errors, $attribute, %istack, $qstack, $line);

sub init () {
    $text       = '';   # text to consume
    $result     = '';   # generated (X)HTML
    @errors     = ();   # um, ... no clue!
    $attribute  = '';   # token attribute (link, plain text)
    %istack     = ();   # "stack" for inline content
    $qstack     =  0;   # "stack" for nested quotes
    $line       =  0;   # line nuber of input text
}

# subs i wanna call without parens for better readability;
use subs qw(
        literal sbc
        block quote ulist ulitem olist olitem paragraph
        inline emphasis strong hyperlink plain
    );

# language handling
my @lang = qw(english german);  # available languages
my $lang = $lang[0];            # default language: english

for my $l (@lang) {
    no strict 'refs';
    *$l = sub { $lang = $l }; # language stub generation
}

# message handling
my %message = (
    e_no_quote_end => {
            $lang[0] => q(No quote end tag ']'),
            $lang[1] => q(Kein Zitatende-Zeichen ']'),
        },
    e_no_emphasis_end => {
            $lang[0] => q(No emphasis end tag '*'),
            $lang[1] => q(Kein Betonungs-Endezeichen '*'),
        },
    e_no_strong_end => {
            $lang[0] => q(No strong end tag '_'),
            $lang[1] => q(Kein Hervorhebungs-Endezeichen '_'),
        },
    e_no_hyperlink_end => {
            $lang[0] => q(No hyperlink end tag '>'),
            $lang[1] => q(Kein Hyperlink-Endezeichen '>'),
        },
    e_unknown_token => {
            $lang[0] => q(Unknown token),
            $lang[1] => q(Unbekanntes Zeichen),
        },
    on_line => {
            $lang[0] => q(around logical line),
            $lang[1] => q(um logische Zeile),
        },
);

sub error ($) {
    my ($error) = @_;
    push @errors, $message{"e_$error"}{$lang}
                    . " " . $message{'on_line'}{$lang} . " $line";
}

# token "table" with matchings
my %token = (
        EMPHASIS        =>  qr{\*},
        STRONG          =>  qr{_},
        HYPERLINK_START =>  qr{<(https?://[^ >\n]+) *},
        HYPERLINK_END   =>  qr{>},
        QUOTE_START     =>  qr{\n+\[\n?},
        QUOTE_END       =>  qr{\] *\n+},
        QUOTE_END_CITE  =>  qr{\] *},
        UL_BULLET       =>  qr{\n+- *},
        OL_BULLET       =>  qr{\n+# *},
        LINEBREAK       =>  qr{\n+},
        PLAIN           =>  qr{((?:[^*_<>\[\]#\\\n]+|\\[*_<>\[\]#\\\n])*)},
    );

sub _pre_translate ($) {
    my $text = shift;
    $text =~ s/&/&amp;/g;
    $text =~ s/\\</&lt;/g;
    $text =~ s/\\>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/ +/ /g;
    return $text;
}

sub _post_translate ($) {
    my $text = shift;
    $text =~ s/\\([*_<>\[\]#\\])/$1/g;
    return $text;
}

# here we go!
sub sbc_translate ($) {
    init();
    $text   = shift || return;
    $text   = _pre_translate($text);
    $text   = "\n$text\n";
    $text   =~ s/[\r\n]+/\n/g;
    $result = sbc; # parse it.
    $result = _post_translate($result);
    $result =~ s/\\\n/<br>/g;
    error('unknown_token') unless $text =~ /^\n*$/;
    return wantarray ? ($result, \@errors) : $result;
}

sub sbc_translate_inline ($) {
    init();
    $text   = shift || return;
    $text   = _pre_translate($text);
    $text   =~ s/[\r\n]+//g;
    $result = inline;
    $result = _post_translate($result);
    error('unknown_token') unless $text =~ /^\n*$/;
    return wantarray ? ($result, \@errors) : $result;
}

# private parsing subs. don't use outside!
sub literal ($;$) {
    my $regex       = shift;
    my $replacement = shift || '';
    my $success     = $text =~ s/^(?:$regex)/$replacement/;
       $attribute   = $1 || undef;
    return $success;
}

sub sbc () {
    my ($sbc, $block) = ('');
    $sbc .= $block while $block = block;
    return qq($sbc);
}

sub block () {
    quote or ulist or olist or paragraph;
}

sub quote () {
    literal $token{QUOTE_START}, "\n" or return;
    $line++;
    $qstack++;
    my $quote = sbc;
    $qstack--;
    literal $token{QUOTE_END}, "\n" and return
        qq(<div class="quote"><blockquote>\n$quote</blockquote></div>\n);
    literal $token{QUOTE_END_CITE} and do {
            my $cite = inline;
            return qq(<div class="quote"><cite>$cite</cite>)
                .  qq(<blockquote>\n$quote</blockquote></div>\n);
        };
    error('no_quote_end');
    return qq(<div class="quote"><blockquote>\n$quote</blockquote></div>\n);
}

sub ulist () {
    my ($ulist, $ulitem);
    $ulist .= $ulitem while $ulitem = ulitem;
    return unless defined $ulist and $ulist ne '';
    return qq(<ul>\n$ulist</ul>\n);
}

sub ulitem () {
    literal $token{UL_BULLET} or return;
    $line++;
    my $ulitem = inline;
    return qq(\t<li>$ulitem</li>\n);
}

sub olist () {
    my ($olist, $olitem);
    $olist .= $olitem while $olitem = olitem;
    return unless defined $olist and $olist ne '';
    return qq(<ol>\n$olist</ol>\n);
}

sub olitem () {
    literal $token{OL_BULLET} or return;
    $line++;
    my $olitem = inline;
    return qq(\t<li>$olitem</li>\n);
}

sub paragraph () {
    literal $token{LINEBREAK} or return;
    $line++;
    my $paragraph = inline;
    literal $token{LINEBREAK}, "\n" or do { $line--; return }
        unless $qstack;
    return $paragraph !~ /^\s*$/ ? qq(<p>$paragraph</p>\n) : "\n";
}

sub inline () {
    my $inline = '';
    while (1) {
        if (!$istack{EMPHASIS} and defined( my $emphasis = emphasis )) {
            $inline .= $emphasis; next
        }
        elsif (!$istack{STRONG} and defined( my $strong = strong )) {
            $inline .= $strong; next
        }
        elsif (!$istack{HYPERLINK} and defined( my $hyperlink = hyperlink )) {
            $inline .= $hyperlink; next
        }
        elsif (defined( my $plain = plain )) {
            $inline .= $plain; next
        }
        last
    }
    return  $inline;
}

sub emphasis () {
    literal $token{EMPHASIS} or return;
    $istack{EMPHASIS}++;
    my ($emphasis, $inline) = ('');
    $emphasis .= $inline while $inline = inline;
    literal $token{EMPHASIS} or error('no_emphasis_end');
    $istack{EMPHASIS}--;
    return $emphasis ne '' ? qq(<em>$emphasis</em>) : '';
}

sub strong () {
    literal $token{STRONG} or return;
    $istack{STRONG}++;
    my ($strong, $inline) = ('');
    $strong .= $inline while $inline = inline;
    literal $token{STRONG} or error('no_strong_end');
    $istack{STRONG}--;
    return $strong ne '' ? qq(<strong>$strong</strong>) : '';
}

sub hyperlink () {
    literal $token{HYPERLINK_START} or return;
    $istack{HYPERLINK}++;
    my ($url, $link, $inline) = ($attribute, '');
    $link .= $inline while $inline = inline;
    $link = $url if $link =~ /^ *$/;
    literal $token{HYPERLINK_END} or error('no_hyperlink_end');
    $istack{HYPERLINK}--;
    return $link ne '' ? qq(<a href="$url">$link</a>) : '';
}

sub plain () {
    literal $token{PLAIN} and return $attribute;
}

# SBC quoting
sub sbc_quote ($;$) {
    my $sbc     = shift;
    my $cite    = shift || '';
    return qq([\n$sbc\n]$cite\n);
}

# SBC HTML description
sub sbc_description () {
    my %desc = (
            $lang[0] => <<DESC_EN,
Simple Blog Code is easy. Paragraphs are directly translated in paragraphs. Codes in paragraphs:
- _\\*foo\\*_ emphasis: *foo*
- _\\_bar\\__ strong emphasis: _bar_
- _\\<http://www.example.org\\>_ hyperlinks with its URL as text: <http://www.example.org>
- _\\<http://www.example.org baz\\>_ hyperlinks with *baz* as text: <http://www.example.org baz>
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
    return scalar sbc_translate($desc{$lang});
}

1;

__END__

=head1 NAME

HTML::SBC - simple blog code for valid (X)HTML

=head1 VERSION

This document describes version 0.08 of HTML::SBC from June 22, 2006.

=head1 SYNOPSIS

    use HTML::SBC qw(:all);

    my ($html, $errors) = sbc_translate($text);

=head1 DESCRIPTION

I<Simple blog code> is a simple markup language. You can use it for guest books,
blogs, wikis, boards and various other web applications. It produces valid and
semantic (X)HTML from input and is patterned on that tiny usenet markups like
*B<bold>* and _underline_. See L</Language description> for details.

HTML::SBC tries to give useful error messages and guess the right translation
even with invalid input. It will always produce valid (X)HTML.

=head2 Translation

You can choose a different output language before translating (English by
default) These additional languages are available:

=over 4

=item

German

    $HTML::SBC::german();

=back

Now, C<HTML::SBC::sbc_translate()> (importable) tries a simple blog code
translation of given input and returns B<a list> with the translation and an
array reference with some error messages:

    my ($html, $errors) = sbc_translate($text);
    print "$_\n" for @$errors;

If you want to translate in I<quirks mode>, just ignore the error messages,
evaluate C<sbc_translate()> in scalar context:

    my $html = sbc_translate($text);

If you have some text in simple blog code C<$original> and you want it to be
sbc-quoted (e. g. for reply functionality in boards), just use

    my $reply = sbc_quote($original);

or add the author's name:

    my $reply = sbc_quote($original, $author);

Additionally, you can use HTML::SBC for one-liners (HTML text fields):

    my $line = sbc_translate_inline($line);

If you want some newbies to use SBC, just show them our SBC language
description:

    my $description = sbc_description();

and embed this in your HTML document. The C<sbc_description()>'s result is HTML.

To import these functions, C<use()> HTML::SBC as described below:

    use HTML::SBC;                      # nothing
    use HTML::SBC qw(sbc_translate);    # nothing but sbc_translate()
    ...
    use HTML::SBC qw(:all);             # import all subs
                                        # except language setter

=head2 Language description

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

=head1 BUGS

This module is in B<BETA STATUS>. I love bug reports and other feedback.

=head1 AUTHOR

Mirko Westermeier (mail@memowe.de)

=head1 COPYRIGHT and LICENSE

Copyright (C) 2005, 2006 by Mirko Westermeier

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

