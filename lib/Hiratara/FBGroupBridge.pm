package Hiratara::FBGroupBridge;
use strict;
use warnings;
use Class::Accessor::Lite (
    rw => [qw/config_file config/],
);
our $VERSION = '0.01';

our $INSTANCE;

sub init {
    my $class = shift;
    warn "init() was called more than twice." if $INSTANCE;

    $INSTANCE = $class->new(@_);
}

sub instance { $INSTANCE or die "You must call init() first." }

sub new {
    my ($class, %params) = @_;
    my $config_file = delete $params{config_file}
                                            or die "Didn't specify config_file";

    my $config = do $config_file;

    bless {
        config_file => $config_file,
        config => $config,
    } => $class;
}

1;
__END__

=head1 NAME

Hiratara::FBGroupBridge -

=head1 SYNOPSIS

  use Hiratara::FBGroupBridge;

=head1 DESCRIPTION

Hiratara::FBGroupBridge is

=head1 AUTHOR

hiratara E<lt>hiratara {at} cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
