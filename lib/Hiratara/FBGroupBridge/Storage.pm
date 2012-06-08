package Hiratara::FBGroupBridge::Storage;
use strict;
use warnings;
use Fcntl ':seek', ':DEFAULT', ':flock';

sub new {
    my $class = shift;
    my %param = @_;
    my $file = delete $param{file};

    sysopen my $fh, $file, O_RDWR | O_CREAT or die $!;
    flock $fh, LOCK_EX or die $!;
    $fh->autoflush(1);

    bless {file => $file, fh => $fh} => $class;
}

sub get_all {
    my $self = shift;
    seek $self->{fh}, 0, SEEK_SET or die $!;

    my %result;
    my $fh = $self->{fh};
    while (<$fh>) {
        tr/\r\n//d;
        my ($key, $value) = split /\t/, $_, 2;
        $result{$key} = $value;
    }

    return \%result;
}

sub set {
    my ($self, $key, $value) = @_;
    my $old_data = $self->get_all;
    $old_data->{$key} = $value;

    my $fh = $self->{fh};
    truncate $fh, 0;
    seek $fh, 0, SEEK_SET or die $!;
    for my $k (keys %$old_data) {
        print $fh join "\t", $k => $old_data->{$k};
        print $fh "\n";
    }
}

sub get {
    my ($self, $key) = @_;
    $self->get_all->{$key};
}

1;
__END__
