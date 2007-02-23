use strict;
use warnings;
use Test::Simple tests => 7;
use HTML::SBC;

my @tests = (
    {   title => 'plain text',
        trans => [ 'foo bar baz',
            qq(foo bar baz),
        ]
    }, {
        title => 'emphasis',
        trans => [ '*foo*',
            qq(<em>foo</em>),
        ]
    }, {
        title => 'strong emphasis',
        trans => [ '_foo_',
            qq(<strong>foo</strong>),
        ]
    }, {
        title => 'hyperlink',
        trans => [ '<http://foo>',
            qq(<a href="http://foo">http://foo</a>),
        ]
    }, {
        title => 'hyperlink with text',
        trans => [ '<http://foo bar>',
            qq(<a href="http://foo">bar</a>),
        ]
    }, {
        title => 'image',
        trans => [ '{http://foo}',
            qq(<img src="http://foo" alt="">),
        ]
    }, {
        title => 'image with alt text',
        trans => [ '{http://foo bar}',
            qq(<img src="http://foo" alt="bar">),
        ]
    },
);

my $t = HTML::SBC->new({ image_support => 1 });
foreach my $test (@tests) {
    ok(
        $t->sbc_inline($test->{trans}[0]) eq $test->{trans}[1],
        $test->{title}
    );
}

__END__
