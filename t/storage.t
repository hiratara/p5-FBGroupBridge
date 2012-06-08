use strict;
use warnings;
use Hiratara::FBGroupBridge::Storage;
use File::Temp qw/tmpnam/;
use Test::More;

my $filename = tmpnam;

my $storage = Hiratara::FBGroupBridge::Storage->new(file => $filename);
$storage->set("hoge" => 123);
undef $storage;

my $storage2 = Hiratara::FBGroupBridge::Storage->new(file => $filename);
is $storage2->get("hoge"), 123;
undef $storage2;

done_testing;
