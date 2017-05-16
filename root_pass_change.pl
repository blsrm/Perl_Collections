#!/usr/bin/perl -w

#http://www.putorius.net/2011/03/using-perl-to-automate-ssh-login-using.html
#https://serverfault.com/questions/509903/best-way-to-go-about-changing-a-root-password-on-3000-solaris-aix-and-linux-s
#https://github.com/salva/p5-Net-OpenSSH-Parallel/blob/master/sample/parallel_passwd.pl
#http://www.wellho.net/forum/Perl-Programming/User-creation-and-password-setting-in-Perl-code.html
#https://rwmj.wordpress.com/tag/root-password/



use strict;
use Expect;
use FileHandle;
use Term::ReadKey;
use Getopt::Long;
 
my (@hosts,$data,$user);
GetOptions(     'hosts=s'       =>      \@hosts,
                'file=s'        =>      \$data,
                'user=s'        =>      \$user,
                'help'          =>      \&help,
);
 
my $ssh = '/usr/bin/ssh -q';
my $passwd = '/usr/bin/passwd';
my $timeout = 15;
my $username = 'root';
my $logfile = "/tmp/chgPassword.txt";
 
sub help {
        print <<EOL;
 
Usage: $0 [OPTION]
 
        --help display this help and exit
        --file name of the file to read hostsnames from
        --host name of hosts to change password on i.e. host1,host2,host3
 
When using --file make sure host names are seperated by a carrage return.
 
Report bugs to <dave.blackburn\@o2.com>
 
EOL
        exit 1;
}
 
sub getpwd {
 
my $i=1;
my ($npwd,$npwd1);
until ($i == 0){
        print "Please enter a new password for user $username : ";
ReadMode 'noecho';
        $npwd = ReadLine 0;
        chomp $npwd;
        print "\nPlease re enter a the password for user $username : ";
        $npwd1 = ReadLine 0;
        chomp $npwd1;
        ReadMode 'normal';
        print "\n";
        if ( $npwd eq $npwd1 ){
                $i=0;
        }else{
                print "Sorry, passwords do not match.\n";
        }
}
        return ($npwd);
}
 
sub change {
 
my $npwd = shift;
my $server = shift;
my $exp = Expect->spawn("$ssh $server -t  'if [ -f /usr/bin/sudo ] && [ -f /usr/local/bin/sudo ];
        then
                echo TWO sudo binarys installed on $server please fix;
        elif [ -x /usr/bin/sudo ];
        then
                /usr/bin/sudo  $passwd $username;
        elif [ -x /usr/local/bin/sudo ];
        then
                /usr/local/bin/sudo  $passwd $username;
        elif [ -x /opt/sfw/bin/sudo ];
        then
                /opt/sfw/bin/sudo  $passwd $username;
        else
                echo NO SUDO installed
        fi'")or die "Cannot spawn: $!\n";
 
my $spawn_ok=0;
$exp->log_stdout(0);
$exp->debug(0);
#$exp->log_file($logfile);
$exp->expect($timeout,
[
        qr'New',
sub {
                $spawn_ok = 1;
                $exp->send($npwd,"\n");
                exp_continue;
        }
],
[
        qr'^Re',
                sub {
                $spawn_ok = 2;
                $exp->send($npwd,"\n");
                exp_continue;
        }
],
[ eof=>
        sub {
                if ($spawn_ok eq 2 ){
                print "Root Password Changed OK on $server\n";
                } else {
                print "ERROR code $spawn_ok connecting to $server\n";
        }
}
],
[ timeout =>
        sub {
                print "ERROR Timeout after $timeout seconds to $server !\n";
        }
],
 
); }
 
#
# Main
#
if ( (defined($data) && @hosts) ){
        print "\n\t*** You cannot use --host and --file at the same time ***\n\n";
}elsif (defined($data)){
        my $fh = new FileHandle $data, "r";
        if (defined $fh) {
        my $passwd=getpwd();
                while (<$fh>){
                        chomp;
                        change ($passwd,$_);
        }
                undef $fh;
        }else{
                print "\nCannot find the file $data\n";
        }
}elsif (@hosts){
        my $passwd=getpwd();
        foreach (split(/,/, $hosts[0])){
                change ($passwd,$_);
        }
}else{
        help();
}
