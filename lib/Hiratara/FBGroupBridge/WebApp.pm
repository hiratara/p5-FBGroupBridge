package Hiratara::FBGroupBridge::WebApp;
use strict;
use warnings;
use Plack::Request;
use Facebook::Graph;
use Class::Accessor::Lite (
    new => 1,
    rw => [qw/app_base/],
);

sub config {
    my $self = shift;
    my $config = do ($self->app_base . "/config.pl");

    no warnings qw/redefine/;
    *config = sub { $config };
    goto &config;
}

sub _first_page {
    my ($self, $req, $res) = @_;

    my $fb = Facebook::Graph->new(
        postback => $self->config->{postback_url},
        app_id   => $self->config->{api_id},
        secret   => $self->config->{app_secret},
    );

    $res->redirect(
        $fb->authorize->extend_permissions('user_groups')->uri_as_string
    );
}

sub _second_page {
    my ($self, $req, $res) = @_;

    my $code = $req->param('code') or die "[BUG]Unexpected status";

    my $fb = Facebook::Graph->new(
        postback => $self->config->{postback_url},
        app_id   => $self->config->{api_id},
        secret   => $self->config->{app_secret},
    );

    $fb->request_access_token($code);
    $res->body($fb->access_token);
}

sub call {
    my $self = shift;
    my ($req, $res) = @_;

    $req->param('code') ? $self->_second_page(@_) : $self->_first_page(@_);
}

sub to_psgi {
    my $self = shift;
    sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        my $res = $req->new_response(200);
        $self->call($req, $res);
        $res->finalize;
    };
}

1;
__END__
