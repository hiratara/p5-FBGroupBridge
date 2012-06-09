#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/dirname/;
use File::Spec ();
our $DIRNAME;
BEGIN { $DIRNAME = File::Spec->rel2abs(dirname __FILE__) }
use lib "$DIRNAME/../lib";
use Hiratara::FBGroupBridge;
use Hiratara::FBGroupBridge::Batch;

Hiratara::FBGroupBridge->init(config_file => "$DIRNAME/../config.pl");
Hiratara::FBGroupBridge::Batch->new->run;
