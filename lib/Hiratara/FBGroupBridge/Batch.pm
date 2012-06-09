package Hiratara::FBGroupBridge::Batch;
use strict;
use warnings;
use utf8;
use Encode qw/encode/;
use Facebook::Graph;
use Time::Piece;
use Time::Seconds qw/ONE_DAY/;
use Email::Simple;
use Email::Sender::Simple qw/sendmail/;
use Email::Sender::Transport::SMTP;
use Text::Xslate;
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

sub check_token {
    my $self = shift;

    my $now = localtime;
    my $expires = localtime($self->storage->get('access_token_expires'));

    if ($expires - ONE_DAY * 7 < $now) {
        my $config = Hiratara::FBGroupBridge->instance->config;
        $self->send_emails([
            From => $config->{your_email},
            To => $config->{your_email},
            Subject => "Please update your access token",
        ], <<__BODY__);
Please update your access token by following URL;
$config->{postback_url}
__BODY__
    }

    die "access token was expired on $expires" if $expires < $now;
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

sub parse_email {
    my ($self, $email_text) = @_;
    my ($header_text, $body) = split qr/(?:\x0d?\x0a){2}/sm, $email_text, 2;

    return [$header_text =~ /^([^:]+):\s*(.*)$/gm], $body;
}

sub send_emails {
    my ($self, $headers, $body) = @_;
    my $config = Hiratara::FBGroupBridge->instance->config;

    my $transport = Email::Sender::Transport::SMTP->new({
        host => $config->{smtp_host},
        port => $config->{smtp_port},
    });

    # encode header
    my @encoded_headers;
    while (my ($key, $value) = splice @$headers, 0, 2) {
        push @encoded_headers,
                            $key => encode('MIME-Header-ISO_2022_JP' => $value);
    }

    my $email = Email::Simple->create(
        header => \@encoded_headers,
        body => encode('iso-2022-jp' => $body),
        attributes => {
            content_type => 'text/plain',
            charset      => 'ISO-2022-JP',
            encoding     => '7bit',
        },
    );
    sendmail($email, {transport => $transport});
}

sub run {
    my $self = shift;
    my $config = Hiratara::FBGroupBridge->instance->config;

    $self->check_token;

    my $time_to = localtime;
    my $time_from;
    if (my $epoch_from = $self->storage->get('current_time')) {
        $time_from = localtime($epoch_from);
    } else {
        $time_from = $time_to - ONE_DAY;
    }

    # check new entries
    my @entries = $self->fetch_entries_by_period($time_from, $time_to);
    die "Didn't have new entries after $time_from." unless @entries;

    # send email
    my $tx = Text::Xslate->new(
        path => "$config->{app_base}/batch",
        type => 'text',
    );
    my $email_text = $tx->render("mail.tx" => {
        entries => \@entries,
        time_from => $time_from,
        time_to => $time_to,
    });
    my ($headers, $body) = $self->parse_email($email_text);

    $self->send_emails($headers, $body);

    # save when we checked entries last
    $self->storage->set('current_time' => $time_to->epoch);
}

1;
__END__
