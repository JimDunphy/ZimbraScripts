#!/usr/bin/perl

# Author: GPT4o and Claude 3.5 Sonnet
# Human: Jim Dunphy
# License (ISC): It's yours. Enjoy
# 1/22/2025
#
# usage: zm-audit-log.pl
#
# % zm-audit-log.pl --help
# Zimbra Audit Log Analyzer version 1.0.1
# 
# Usage: zm-audit-log.pl [options]
# Options:
#   --dir=DIR     Specify log directory (default: /opt/zimbra/log)
#   --file=FILE   Specify single log file (default: DIR/audit.log)
#   --all         Process all audit.log* files in directory
#   --user=EMAIL  Show details for specific user
#   --list        List all users
#   --help        Show this help message
#   --version     Show version information
#
# Caveat: 
#   Permission: /opt/zimbra/log/audit.log is owned by zimbra.  Recommendation is to run this as the zimbra user or 
#               add your account to the zimbra group.
#   Failures: Currently not checking for failures yet.
#
# Sample output:
#
# % zm-audit-log.pl --file=/tmp/myaudit.log
#Processing /tmp/myaudit.log...
#+--------------------------------+---------------------+-----------------------+--------------------------------------------------------------------+
#| Email                          | Last Seen           | Auth Methods          | IP Addresses                                                       |
#+--------------------------------+---------------------+-----------------------+--------------------------------------------------------------------+
#| Dlastname@example.com          | 2025-01-16 09:02:03 | WebClient             | X.X.X.X                                                            |
#| Flastname@example.com          | 2025-01-21 14:30:41 | WebClient             | 174.224.208.9, 174.224.211.89, 174.224.212.99, 174.239.114.245,    |
#|                                                                                174.239.121.80, X.X.X.X                                            |
#| Fname.Alastname@example.com    | 2025-01-21 00:38:32 | POP3                  | X.X.X.X                                                            |
#| archive@example.net            | 2025-01-20 23:38:54 | POP3                  | X.X.X.X                                                            |
#| ceo@example.com                | 2025-01-21 00:08:54 | POP3                  | X.X.X.X                                                            |
#| dan.Blastname@example.com      | 2025-01-20 19:21:35 | WebClient             | X.X.X.X                                                            |
#| jackie.Clastname@example.com   | 2025-01-21 07:28:47 | WebClient             | X.X.X.X                                                            |
#| jad@example.com                | 2025-01-21 15:26:24 | IMAP                  | X.X.X.X                                                            |
#| jesse@example.com              | 2025-01-21 22:53:44 | ActiveSync, WebClient | 172.56.100.202, 172.56.100.244, 172.56.100.68, 172.56.101.140,     |
#|                                                                                172.56.101.18, 172.56.101.190, 172.56.101.32, 172.56.101.58,       |
#|                                                                                172.56.101.88, 172.56.102.100, 172.56.102.106, 172.56.102.108,     |
#|                                                                                172.56.102.182, 172.56.102.188, 172.56.102.198, 172.56.102.254,    |
#|                                                                                172.56.103.108, 172.56.103.202, 172.56.103.236, 172.56.103.26,     |
#|                                                                                172.56.103.90, 172.56.98.102, 172.56.98.106, 172.56.98.126,        |
#|                                                                                172.56.98.163, 172.56.98.36, 172.56.98.45, 172.56.98.65,           |
#|                                                                                172.56.99.103, 172.56.99.127, 172.56.99.35, 174.211.96.19,         |
#|                                                                                35.137.195.0, X.X.X.X                                              |
#| michelle.Elastname@example.com | 2025-01-21 06:37:33 | WebClient             | X.X.X.X                                                            |
#| name@example.com               | 2025-01-21 00:08:54 | POP3                  | X.X.X.X                                                            |
#+--------------------------------+---------------------+-----------------------+--------------------------------------------------------------------+
#
# % zm-audit-log.pl --user=name@Dlastname@example.com 
# 

use strict;
use warnings;
use Data::Dumper;
use Time::Piece;
use Getopt::Long;
use Term::ANSIColor;

our $VERSION = "1.0.1";  # Version tracking

# Command line options
my $log_dir = '/opt/zimbra/log';
my $log_file = "$log_dir/audit.log";
my $target_user = '';
my $list_users = 0;
my $help = 0;
my $show_version = 0;
my $process_all = 0;

GetOptions(
    "file=s"   => \$log_file,
    "dir=s"    => \$log_dir,
    "user=s"   => \$target_user,
    "list"     => \$list_users,
    "help"     => \$help,
    "version"  => \$show_version,
    "all"      => \$process_all
) or die "Error in command line arguments\n";

if ($show_version) {
    print "Zimbra Audit Log Analyzer version $VERSION\n";
    exit;
}

if ($help) {
    print "Zimbra Audit Log Analyzer version $VERSION\n\n";
    print "Usage: $0 [options]\n";
    print "Options:\n";
    print "  --dir=DIR     Specify log directory (default: /opt/zimbra/log)\n";
    print "  --file=FILE   Specify single log file (default: DIR/audit.log)\n";
    print "  --all         Process all audit.log* files in directory\n";
    print "  --user=EMAIL  Show details for specific user\n";
    print "  --list        List all users\n";
    print "  --help        Show this help message\n";
    print "  --version     Show version information\n";
    exit;
}

# Data structures to store our analysis
my %users;         # Store user activity
my %devices;       # Store device information
my %ip_tracking;   # Track IP addresses
my %auth_methods;  # Track authentication methods

# Get list of log files to process
sub get_log_files {
    my $dir = shift;
    my @files;
    
    if ($process_all) {
        # Get all audit log files
        @files = glob("$dir/audit.log*");
        print "Found ", scalar(@files), " audit log files to process.\n";
    } else {
        @files = ($log_file);
    }
    
    return sort @files;
}

# Process a single log file
sub process_log_file {
    my ($file) = @_;
    my $errors = 0;
    
    print "Processing $file...\n";
    
    # Use zcat -f for both compressed and uncompressed files
    open(my $fh, '-|', "zcat -f $file 2>/dev/null") or do {
        warn "Cannot open $file: $!\n";
        return 1;
    };
    
    while (my $line = <$fh>) {
        chomp $line;
        
        # Skip system zimbra authentication lines
        next if $line =~ /account=zimbra;/;
        
        # Extract timestamp
        my ($timestamp) = $line =~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/;
        next unless $timestamp; # Skip lines without timestamp
        
        # Process app-specific password authentications
        if ($line =~ /successfully logged in with app-specific password/) {
            my ($account) = $line =~ /account ([^ ]+) successfully/;
            my ($ip) = $line =~ /ip=([^;]+)/;

            next unless ($account && $ip);
            $users{$account}{app_specific}{last_seen} = $timestamp;
            $users{$account}{app_specific}{last_ip} = $ip;
            $users{$account}{ips}{$ip}{last_seen} = $timestamp;
            $users{$account}{ips}{$ip}{count}++;
            $auth_methods{$account}{app_specific}++;  # This is the counter that needs to be updated
        }
        # Process ActiveSync authentications
        elsif ($line =~ /Microsoft-Server-ActiveSync/) {
            my ($user) = $line =~ /User=([^&]+)/;
            my ($device_id) = $line =~ /DeviceId=([^&]+)/;
            my ($device_type) = $line =~ /DeviceType=([^&]+)/;
            my ($ip) = $line =~ /ip=([^;]+)/;
            my ($account) = $line =~ /account=([^;]+)/;


            # Skip if we don't have all required fields
            next unless ($user && $device_id && $device_type && $ip && $account);

            # Create/update basic device info
            $users{$account}{active_sync}{last_seen} = $timestamp;
            $users{$account}{active_sync}{devices}{$device_id} = {
                device_type => $device_type,
                model => $device_type,
                last_ip => $ip,
                last_seen => $timestamp
            };
            
            $devices{$device_id}{account} = $account;
            $devices{$device_id}{type} = $device_type;
            $devices{$device_id}{last_seen} = $timestamp;
            
            $users{$account}{ips}{$ip}{last_seen} = $timestamp;
            $users{$account}{ips}{$ip}{count}++;
        }
        # Process 2FA authentications
        elsif ($line =~ /two-factor auth successful/) {
            my ($account) = $line =~ /account=([^;]+)/ ? $1 : $line =~ /name=([^;]+)/ ? $1 : undef;
            next unless ($account && $account =~ /@/);
            
            $users{$account}{security}{auth_type} = "2FA";
            $users{$account}{security}{last_2fa} = $timestamp;
            $auth_methods{$account}{two_factor_auth}++;
        }
        # Process trusted device authentications
        elsif ($line =~ /trusted device verified.*bypassing two-factor auth/) {
            my ($account) = $line =~ /account=([^;]+)/ ? $1 : $line =~ /name=([^;]+)/ ? $1 : undef;
            my ($ip) = $line =~ /ip=([^;]+)/;
            my ($ua) = $line =~ /ua=([^;]+)/;

            # Skip if we don't have required fields or if it's the zimbra account
            next unless ($account && $ip);
            next if $account eq 'zimbra';
            next unless $account =~ /@/;  # Skip invalid email addresses
            
            $users{$account}{security}{auth_type} = "Trusted Device";
            $users{$account}{security}{last_trusted} = $timestamp;
            $auth_methods{$account}{trusted_device}++;

            
            $users{$account}{web_client}{last_seen} = $timestamp;
            $users{$account}{web_client}{last_ip} = $ip;
            $users{$account}{web_client}{user_agent} = $ua if $ua;
            
            $users{$account}{ips}{$ip}{last_seen} = $timestamp;
            $users{$account}{ips}{$ip}{count}++;
        }
        # Process web client authentications and batch requests
        elsif ($line =~ /ZimbraWebClient/ || $line =~ /BatchRequest/) {
            my ($account) = $line =~ /account=([^;]+)/ ? $1 : $line =~ /name=([^;]+)/ ? $1 : undef;
            my ($ip) = $line =~ /oip=([^;]+)/;
            my ($ua) = $line =~ /ua=([^;]+)/;
            
            # Skip if we don't have required fields or if it's the zimbra account
            next unless ($account && $ip);
            next if $account eq 'zimbra';
            next unless $account =~ /@/;  # Skip invalid email addresses
            
            $users{$account}{web_client}{last_seen} = $timestamp;
            $users{$account}{web_client}{last_ip} = $ip;
            $users{$account}{web_client}{user_agent} = $ua if $ua;
            
            $users{$account}{ips}{$ip}{last_seen} = $timestamp;
            $users{$account}{ips}{$ip}{count}++;
        }
        # Process POP3/IMAP authentications
        elsif ($line =~ /protocol=(pop3|imap);/) {
            my ($account) = $line =~ /account=([^;]+)/;
            my ($ip) = $line =~ /oip=([^;]+)/;
            my ($protocol) = $line =~ /protocol=([^;]+)/;
            my ($oip) = $line =~ /oip=([^;]+)/;  # Original IP if coming through proxy

    
            next unless ($account && $ip);
            next if $account eq 'zimbra';
            next unless $account =~ /@/;  # Skip invalid email addresses
    
#%%%
#print "protocol [$protocol] time [$timestamp] \n"; exit;

            $users{$account}{"${protocol}_client"}{last_seen} = $timestamp;
            $users{$account}{"${protocol}_client"}{last_ip} = $ip;
    
            $users{$account}{ips}{$ip}{last_seen} = $timestamp;
            $users{$account}{ips}{$ip}{count}++;
            $auth_methods{$account}{$protocol}++;

        }
    }
    
    close($fh);
    return 0;
}

# Process log files
my $total_errors = 0;
foreach my $file (get_log_files($log_dir)) {
    $total_errors += process_log_file($file);
}

# Report any processing errors
if ($total_errors > 0) {
    print "\nWarning: Encountered problems with $total_errors file(s)\n";
}

# Default to --list if no specific action
if (!$target_user && !$list_users) {
    $list_users = 1;
}

# List all users if requested
if ($list_users) {
    my @rows;
    foreach my $user (sort keys %users) {
        my @methods;
        push @methods, "ActiveSync" if exists $users{$user}{active_sync};
        push @methods, "WebClient" if exists $users{$user}{web_client};
        push @methods, "AppSpecific" if exists $users{$user}{app_specific};
        push @methods, "POP3" if exists $users{$user}{pop3_client};
        push @methods, "IMAP" if exists $users{$user}{imap_client};

        # Add 2FA status to methods if applicable
        if (exists $users{$user}{security}) {
            if (exists $users{$user}{security}{last_2fa}) {
                push @methods, "2FA";
            }
            elsif (exists $users{$user}{security}{last_trusted}) {
                push @methods, "2FA (Trusted)";
            }
        }
        
        my $last_seen = "";
        foreach my $type (qw(active_sync web_client app_specific pop3_client imap_client)) {
            if (exists $users{$user}{$type} && exists $users{$user}{$type}{last_seen}) {
                $last_seen = $users{$user}{$type}{last_seen}
                    if (!$last_seen || $users{$user}{$type}{last_seen} gt $last_seen);
            }
        }

        # Format the IP addresses, 4 per line
        my @ips = sort keys %{$users{$user}{ips}};
        my $ips_per_line = 4;
        my $formatted_ips = '';
        
        # Format first line
        for (my $i = 0; $i < @ips; $i++) {
            $formatted_ips .= $ips[$i];
            if ($i < $#ips) {  # If not the last IP
                $formatted_ips .= ", ";
                if (($i + 1) % $ips_per_line == 0) {
                    $formatted_ips .= "\n";  # Just newline, no indentation here
                }
            }
        }

        push @rows, [
            $user,
            $last_seen,
            join(", ", @methods),
            $formatted_ips
        ];

    }
    print format_all_table(['Email', 'Last Seen', 'Auth Methods', 'IP Addresses'], \@rows);
    exit;
}

# Show details for specific user
if ($target_user) {
    if (!exists $users{$target_user}) {
        print "No data found for user: $target_user\n";
        exit 1;
    }
    
    print colored(['bold'], "\nUser Details: $target_user\n\n");

    # Show POP3 access
    if (exists $users{$target_user}{pop3_client}) {
        print colored(['bold'], "POP3 Client Access:\n");
        my @rows;
        my $pop3_info = $users{$target_user}{pop3_client};
        push @rows, [
            $pop3_info->{last_seen} // 'N/A',
            $pop3_info->{last_ip} // 'N/A',
            $pop3_info->{orig_ip} // 'N/A'
        ];
        print format_table(['Last Seen', 'Last IP', 'Original IP'], \@rows);
        print "\n";
    }

    # Show IMAP access
    if (exists $users{$target_user}{imap_client}) {
        print colored(['bold'], "IMAP Client Access:\n");
        my @rows;
        my $imap_info = $users{$target_user}{imap_client};
        push @rows, [
            $imap_info->{last_seen} // 'N/A',
            $imap_info->{last_ip} // 'N/A',
            $imap_info->{orig_ip} // 'N/A'
        ];
        print format_table(['Last Seen', 'Last IP', 'Original IP'], \@rows);
        print "\n";
    }
    
    # Show devices
    if (exists $users{$target_user}{active_sync}) {
        print colored(['bold'], "ActiveSync Devices:\n");
        my @rows;
        foreach my $device (sort keys %{$users{$target_user}{active_sync}{devices}}) {
            my $dev_info = $users{$target_user}{active_sync}{devices}{$device};
            push @rows, [
                $device,
                $dev_info->{model},
                $dev_info->{last_seen},
                $dev_info->{last_ip}
            ];
        }
        print format_table(['Device ID', 'Device Model', 'Last Seen', 'Last IP'], \@rows);
        print "\n";
    }
    
    # Show web client access
    if (exists $users{$target_user}{web_client}) {
        print colored(['bold'], "Web Client Access:\n");
        my @rows;
        my $web_info = $users{$target_user}{web_client};
        push @rows, [
            $web_info->{last_seen} // 'N/A',
            $web_info->{last_ip} // 'N/A',
            $web_info->{user_agent} // 'N/A'
        ];
        print format_table(['Last Seen', 'Last IP', 'User Agent'], \@rows);
        print "\n";
    }
    
    # Show security info
    if (exists $users{$target_user}{security} || exists $auth_methods{$target_user}) {
        print colored(['bold'], "Security Info:\n");
        my @rows;
        if (exists $users{$target_user}{security}) {
            if (exists $users{$target_user}{security}{last_2fa}) {
                push @rows, ["2FA", $users{$target_user}{security}{last_2fa}, "Last successful 2FA login"];
            }
            if (exists $users{$target_user}{security}{last_trusted}) {
                push @rows, ["Trusted Device", $users{$target_user}{security}{last_trusted}, "Last trusted device login"];
            }
        }
        my $two_fa_count = $auth_methods{$target_user}{two_factor_auth} // 0;
        my $trusted_count = $auth_methods{$target_user}{trusted_device} // 0;
        push @rows, ["2FA Logins", $two_fa_count, "Total 2FA authentications"];
        push @rows, ["Trusted Device Logins", $trusted_count, "Total trusted device authentications"];
        
        print format_table(['Type', 'Value/Time', 'Notes'], \@rows) if @rows;
        print "\n";
    }
    
    # Show IP history
    if (exists $users{$target_user}{ips}) {
        print colored(['bold'], "IP Address History:\n");
        my @rows;
        foreach my $ip (sort keys %{$users{$target_user}{ips}}) {
            push @rows, [
                $ip,
                $users{$target_user}{ips}{$ip}{last_seen} // 'N/A',
                $users{$target_user}{ips}{$ip}{count} // 0
            ];
        }
        print format_table(['IP Address', 'Last Seen', 'Access Count'], \@rows);
        print "\n";
    }
    
    # Show authentication methods
    if (exists $auth_methods{$target_user}) {
        print colored(['bold'], "Authentication Summary:\n");
        my @rows;
        push @rows, ["Two-Factor Auth", $auth_methods{$target_user}{two_factor_auth} // 0];
        push @rows, ["Trusted Device", $auth_methods{$target_user}{trusted_device} // 0];
        push @rows, ["App-Specific Password", $auth_methods{$target_user}{app_specific} // 0];
        push @rows, ["POP3 Access", $auth_methods{$target_user}{pop3} // 0];
        push @rows, ["IMAP Access", $auth_methods{$target_user}{imap} // 0];
        print format_table(['Method', 'Count'], \@rows);
        print "\n";
    }
}

# Table formatting function
sub format_all_table {
    my ($headers, $rows) = @_;
    my @col_widths;
    
    # Calculate column widths
    for my $col (0..$#$headers) {

       # Special handling for IP address column
       if ($col == 3) {  # IP Addresses column
           $col_widths[$col] = (15 * 4) + (2 * 3) + 2;  # 4 IPs * 15 chars + 3 separators * 2 chars + padding
       } else {
           # Get substring up to the first newline, if present
           my $header_value = $headers->[$col] =~ /\n/ ? (split(/\n/, $headers->[$col]))[0] : $headers->[$col];
           my $max_width = length($header_value);
           for my $row (@$rows) {
               my $len_value = $row->[$col] =~ /\n/ ? (split(/\n/, $row->[$col]))[0] : $row->[$col];
               my $len = length($len_value);
               $max_width = $len if $len > $max_width;
           }
           $col_widths[$col] = $max_width + 2; # Add padding
       }
   }
    
    # Calculate IP column start position (sum of previous column widths plus separators)
    my $ip_column_start = 1;  # Start after first |
    for my $i (0..2) {  # Add widths of first three columns
        $ip_column_start += $col_widths[$i] + 1;  # +1 for each separator
    }
    
    # Format header
    my $separator = '+' . join('+', map {'-' x $_} @col_widths) . '+';
    my $output = $separator . "\n";
    $output .= '|' . join('|', map {sprintf("%-*s", $col_widths[$_], " $headers->[$_]")} 0..$#$headers) . "|\n";
    $output .= $separator . "\n";
    
    # Format rows with proper multi-line handling
    for my $row (@$rows) {
        my @formatted_columns = ();
        
        # Handle first three columns normally
        for my $col (0..2) {
            my $cell_value = $row->[$col] // '';
            push @formatted_columns, sprintf("%-*s", $col_widths[$col], " $cell_value");
        }
        
        # Special handling for IP address column
        my $ip_value = $row->[3] // '';
        my @ip_lines = split(/\n/, $ip_value);
        
        # Format first line of IPs
        push @formatted_columns, sprintf("%-*s", $col_widths[3], " $ip_lines[0]");
        
        # Output the first line
        $output .= '|' . join('|', @formatted_columns) . "|\n";
        
        # Output continuation lines for IPs if they exist
        for my $i (1..$#ip_lines) {
            $output .= '|' . (' ' x ($ip_column_start - 1)) . sprintf("%-*s", $col_widths[3], " $ip_lines[$i]") . "|\n";
        }

    }
    
    $output .= $separator . "\n";
    return $output;
}

# Table formatting function
# Table formatting function
sub format_table {
    my ($headers, $rows) = @_;
    my @col_widths;
    
    # Calculate column widths
    for my $col (0..$#$headers) {
        my $max_width = length($headers->[$col]);
        for my $row (@$rows) {
            my $len = length($row->[$col] // '');
            $max_width = $len if $len > $max_width;
        }
        $col_widths[$col] = $max_width + 2; # Add padding
    }
    
    # Format header
    my $separator = '+' . join('+', map {'-' x $_} @col_widths) . '+';
    my $output = $separator . "\n";
    $output .= '|' . join('|', map {sprintf("%-*s", $col_widths[$_], " $headers->[$_]")} 0..$#$headers) . "|\n";
    $output .= $separator . "\n";
    
    # Format rows
    for my $row (@$rows) {
        $output .= '|' . join('|', map {sprintf("%-*s", $col_widths[$_], " " . ($row->[$_] // ''))} 0..$#$headers) . "|\n";
    }
    $output .= $separator . "\n";
    
    return $output;
}

