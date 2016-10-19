#!/usr/bin/env perl
# Tools to detect AWS EC2 Scheduled Events (We can't receive email Q_Q)
# Ref: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring-instances-status-check_sched.html

use strict;
use warnings;
use 5.010;
use Getopt::Long qw(GetOptions);
use WebService::Slack::IncomingWebHook;

my @regions = ("ap-northeast-1","ap-northeast-2", "ap-southeast-1", "ap-southeast-2", "eu-central-1", "us-west-2");
my $msg="";
my $aws_credential_file = "";
my $slack_token_file = "";

# Get file
GetOptions(
    'aws-credential=s' => \$aws_credential_file,
    'slack-token' => \$slack_token_file,
) or die "Usage: $0 --aws-credential /path/to/file  --slack-token /path/to/file";

if ( $aws_credential_file eq "" || $slack_token_file eq ""  ) {
    say "Usage: $0 --aws-credential /path/to/file  --slack-token /path/to/file";
    exit;
}

# read credential
open(CREDENTIAL, $aws_credential_file) or die("Could not open file.");
my $aws_access_key_id = <CREDENTIAL>;
my $aws_secret_access_key = <CREDENTIAL>;
chomp $aws_access_key_id;
chomp $aws_secret_access_key;
close(CREDENTIAL);

$ENV{'AWS_ACCESS_KEY_ID'} = $aws_access_key_id;
$ENV{'AWS_SECRET_ACCESS_KEY'} = $aws_secret_access_key;
$ENV{'AWS_DEFAULT_REGION'} = "us-west-2";

foreach my $region (@regions) {
    my $result = `/usr/local/bin/aws --region="$region" ec2 describe-instance-status | jq -r '.InstanceStatuses[].Events' | grep -v null`;
    if ($result ne "") {
        # Need change
        if ( $result !~ "[Completed]") {
            $msg = $msg.$region." Region:\n".$result."\n";
        }
    }
}

if ($msg ne "") {
    open(INFO, $slack_token_file) or die("Could not open file.");

    my $slacktoken = <INFO>;  
    chomp $slacktoken;

    close(INFO);

    my $client = WebService::Slack::IncomingWebHook->new(
        webhook_url => $slacktoken,
        channel     => '#log-monitor',
        icon_emoji  => ':sushi:',
        username    => 'EC2ScheduledEvents',
    );
    $client->post(
        text       => $msg,
    );
}
