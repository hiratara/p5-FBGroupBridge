#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use File::Basename qw/dirname/;
use File::Spec ();
our $APP_BASE;
BEGIN { $APP_BASE = File::Spec->rel2abs(dirname __FILE__) . "/.." }
use lib "$APP_BASE/lib";
use Facebook::Graph;
use Time::Piece;
use Time::Seconds qw/ONE_DAY/;
use Email::Simple;
use Email::Sender::Simple qw/sendmail/;
use Email::Sender::Transport::SMTP;
use Hiratara::FBGroupBridge::Storage;

my $config = do ($APP_BASE . "/config.pl");

my $storage = new Hiratara::FBGroupBridge::Storage(
    file => "$APP_BASE/$config->{storage_path}",
);

my $token = $storage->get('access_token');

my $time_from;
if (my $epoch_from = $storage->get('current_time')) {
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
$storage->set('current_time' => $latest_time->epoch);
