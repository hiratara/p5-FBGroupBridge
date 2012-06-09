#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/dirname/;
use Plack::Loader;

my $app = Plack::Util::load_psgi((dirname __FILE__) . "/app.psgi");
Plack::Loader->auto->run($app);
