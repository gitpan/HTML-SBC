use strict;
use warnings;
use Test::Simple tests => 10;
use Test::Exception;
use UNIVERSAL qw( can );
use HTML::SBC;

my $sbc = HTML::SBC->new();

foreach my $field (qw(
                        language
                        image_support
                        error_callback
                        linkcheck_callback
                        imgcheck_callback
                                            )) {
    ok(
        $sbc->can($field),
        "has accessor for $field"
    );

    lives_ok(
        sub { $sbc->$field($sbc->$field) },
        "default for $field is valid"
    );
}

__END__
