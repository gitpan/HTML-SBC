# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name            'HTML-SBC';
all_from        'lib/HTML/SBC.pm';

# Specific dependencies
requires        'Carp'              => 0;
requires        'Scalar::Util'      => 0;
requires        'List::Util'        => 0;
requires        'Exporter'          => 0;
build_requires  'Test::Simple'      => 0;
build_requires  'Test::More'        => 0;
build_requires  'Test::Exception'   => 0;

auto_install;
WriteAll;
