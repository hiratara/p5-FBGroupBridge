#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/dirname/;
use File::Spec ();
our $APP_BASE;
BEGIN { $APP_BASE = File::Spec->rel2abs(dirname __FILE__) . "/.." }
use lib "$APP_BASE/lib";
use Hiratara::FBGroupBridge::Batch;

my $batch = Hiratara::FBGroupBridge::Batch->new(app_base => $APP_BASE);
$batch->run;
