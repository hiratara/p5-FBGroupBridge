package Hiratara::FBGroupBridge::Batch;
use strict;
use warnings;
use utf8;
use Facebook::Graph;
use Time::Piece;
use Time::Seconds qw/ONE_DAY/;
use Email::Simple;
use Email::Sender::Simple qw/sendmail/;
use Email::Sender::Transport::SMTP;
use Hiratara::FBGroupBridge;
use Hiratara::FBGroupBridge::Storage;
use Class::Accessor::Lite (
    new => 1,
    rw => [qw//],
);

sub storage {
    my $self = shift;
    my $config = Hiratara::FBGroupBridge->instance->config;

    return new Hiratara::FBGroupBridge::Storage(
        file => "$config->{app_base}/$config->{storage_path}",
    );
}

sub run {
    my $self = shift;
    my $config = Hiratara::FBGroupBridge->instance->config;

    my $token = $self->storage->get('access_token');

    my $time_from;
    if (my $epoch_from = $self->storage->get('current_time')) {
        $time_from = localtime($epoch_from);
    } else {
        ($time_from = localtime) -= ONE_DAY;
    }

    # check new entries
    my $fb = Facebook::Graph->new(access_token => $token);

    my $body = '';
    my $latest_time = $time_from;
    my $group_id = $config->{group_id};
    my $url = $fb->query->find("$group_id/feed")->uri_as_string;
    # $url =~ s{\?}{\?limit=25&until=1337329336&};
    for my $post (@{ $fb->query->request($url)->as_hashref->{data} }) {
        my $updated_time = localtime(Time::Piece->strptime(
            $post->{updated_time}, "%Y-%m-%dT%H:%M:%S%z"
        )->epoch);
        $latest_time = $updated_time if $latest_time < $updated_time;
        last if $updated_time < $time_from;

        for my $entry ($post, @{$post->{comments}{data}}) {
            my $created_time = localtime(Time::Piece->strptime(
                $entry->{created_time}, "%Y-%m-%dT%H:%M:%S%z"
            )->epoch);
            next if $created_time <= $time_from;

            $body .= "$entry->{from}{name} ($created_time)\n";
            $body .= $entry->{message} . "\n";
            $body .= "\n";
        }
    }

    die "Didn't have new entries after $time_from." unless $body;

    # send email
    my $transport = Email::Sender::Transport::SMTP->new({
        host => $config->{smtp_host},
        port => $config->{smtp_port},
    });
    my $email = Email::Simple->create(
        header => [
            From    => $config->{mail_from},
            To      => $config->{mail_to},
            Subject => "$time_from\以降の更新",
        ],
        body => $body,
    );
    sendmail($email, {transport => $transport});

    # save when we checked entries last
    $self->storage->set('current_time' => $latest_time->epoch);
}

1;
__END__
