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

sub fetch_entries_by_period {
    my ($self, $time_from, $time_to) = @_;

    my $group_id = Hiratara::FBGroupBridge->instance->config->{group_id};
    my $token = $self->storage->get('access_token');
    my $fb = Facebook::Graph->new(access_token => $token);

    my @results;
    my $url = $fb->query->find("$group_id/feed")->uri_as_string;
    # $url =~ s{\?}{\?limit=25&until=1337329336&};
    for my $post (@{ $fb->query->request($url)->as_hashref->{data} }) {
        my $updated_time = localtime(Time::Piece->strptime(
            $post->{updated_time}, "%Y-%m-%dT%H:%M:%S%z"
        )->epoch);
        last if $updated_time < $time_from;

        for my $entry ($post, @{$post->{comments}{data}}) {
            my $created_time = localtime(Time::Piece->strptime(
                $entry->{created_time}, "%Y-%m-%dT%H:%M:%S%z"
            )->epoch);
            $time_from <= $created_time && $created_time < $time_to or next;

            push @results, {
                time => $created_time,
                name => $entry->{from}{name},
                message => $entry->{message},
            };
        }
    }

    return @results;
}

sub send_emails {
    my ($self, %params) = @_;
    my $config = Hiratara::FBGroupBridge->instance->config;

    my $transport = Email::Sender::Transport::SMTP->new({
        host => $config->{smtp_host},
        port => $config->{smtp_port},
    });
    my $email = Email::Simple->create(
        header => [
            From    => $params{from},
            To      => $params{to},
            Subject => $params{subject},
        ],
        body => $params{body},
    );
    sendmail($email, {transport => $transport});
}

sub run {
    my $self = shift;
    my $config = Hiratara::FBGroupBridge->instance->config;

    my $time_to = localtime;
    my $time_from;
    if (my $epoch_from = $self->storage->get('current_time')) {
        $time_from = localtime($epoch_from);
    } else {
        $time_from = $time_to - ONE_DAY;
    }

    # check new entries
    my $body = '';
    for my $entry ($self->fetch_entries_by_period($time_from, $time_to)) {
        $body .= "$entry->{name} ($entry->{time})\n";
        $body .= $entry->{message} . "\n";
        $body .= "\n";
    }

    die "Didn't have new entries after $time_from." unless $body;

    # send email
    $self->send_emails(
        from => $config->{mail_from},
        to => $config->{mail_to},
        subject => "$time_from\以降の更新",
        body => $body,
    );

    # save when we checked entries last
    $self->storage->set('current_time' => $time_to->epoch);
}

1;
__END__
