# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Package for postfix service tests
#
# Maintainer: Alynx Zhou <alynx.zhou@suse.com>

package services::postfix;
use base 'opensusebasetest';
use testapi;
use utils;
use Utils::Systemd 'disable_and_stop_service';
use mailtest qw(mailx_setup mailx_send_mail);
use strict;
use warnings;

my $postfix_conf = "/etc/postfix/main.cf";
my $postfix_cert = "/etc/postfix/ssl/postfix.crt";
my $postfix_key  = "/etc/postfix/ssl/postfix.key";
my $mail_server_name = 'localhost';
my $username         = 'leli';

sub install_service {
    # Install postfix and required packages
    zypper_call "in postfix cyrus-sasl cyrus-sasl-saslauthd mailx";
}

sub config_service {
    # Bug workaround
    type_string("ln -sf /usr/lib/postfix/bin/postfix-script /usr/lib/postfix/postfix-script\n");
    # Configure postfix with TLS support (only smtpd)
    assert_script_run "curl " . data_url('postfix/main.cf') . " -o $postfix_conf";
    assert_script_run "curl " . data_url('openssl/mail-server-cert.pem') . " -o $postfix_cert";
    assert_script_run "curl " . data_url('openssl/mail-server-key.pem') . " -o $postfix_key";
    assert_script_run "sed -i 's/^#tlsmgr/tlsmgr/' /etc/postfix/master.cf";
    systemctl "restart saslauthd.service";
    systemctl "is-active saslauthd.service";
    systemctl "restart postfix.service";
    systemctl "is-active postfix.service";
}

sub enable_service {
    systemctl 'enable saslauthd.service';
    systemctl 'enable postfix.service';
}

sub start_service {
    systemctl 'start saslauthd.service';
    systemctl 'start postfix.service';
}

# check service is running and enabled
sub check_service {
    systemctl 'is-enabled postfix.service';
    systemctl 'is-active postfix';
}

# check postfix function
sub check_function {
    # Send testing mail
    mailx_setup(ssl => "yes", host => $mail_server_name);
    mailx_send_mail(subject => "openQA Testing", to => "$testapi::username\@$mail_server_name");

    # Verify mail received
    assert_script_run "postfix flush; grep 'openQA Testing' /var/mail/$testapi::username";
}

# check postfix service before and after migration
# stage is 'before' or 'after' system migration.
sub full_postfix_check {
    my ($stage) = @_;
    $stage //= '';
    if ($stage eq 'before') {
        install_service();
        config_service();
        enable_service();
        start_service();
    }
    check_service();
    check_function();
}

1;
