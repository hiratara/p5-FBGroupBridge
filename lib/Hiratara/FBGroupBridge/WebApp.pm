package Hiratara::FBGroupBridge::WebApp;
use strict;
use warnings;
use Plack::Request;
use Facebook::Graph;
use Hiratara::FBGroupBridge;
use Hiratara::FBGroupBridge::Storage;
use Class::Accessor::Lite (
    new => 1,
    rw => [qw//],
);

sub config {
    my $self = shift;
    my $config = Hiratara::FBGroupBridge->instance->config;

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

    my $token_response = $fb->request_access_token($code);
    my $access_token = $token_response->token;
    my $access_token_expires = time + $token_response->expires;

    my $user_id = $fb->fetch('me')->{id};
    if ($user_id eq $self->config->{your_id}) {
        my $storage = Hiratara::FBGroupBridge::Storage->new(
            file => $self->config->{app_base} . '/'
                                              . $self->config->{storage_path},
        );
        $storage->set(access_token => $access_token);
        $storage->set(access_token_expires => $access_token_expires);

        $res->body('Refreshed access token');
    } else {
        $res->body('invalid access');
    }
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
