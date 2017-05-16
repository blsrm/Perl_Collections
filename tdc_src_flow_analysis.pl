#!/tools/user_profile/sharedbin/sparc-sun-solaris8/bin/perl -w

use strict;
use File::Find;
use File::Basename;
use File::Copy;

use vars qw($opt_d $opt_v);
use Getopt::Std;
getopts('d:v');

my $dir = '.';
$dir = $opt_d if $opt_d;

my @files;
my $files_length = 0;

my $prefix = "";
my $postfix = "";
my $match = "";
my $noFlagContent = "";

### Flags
my $nextCurlyFlag = 0;
my $sameLineFlag = 0;
my $sameNextLineFlag = 0;
my $noFlag = 0;
my $ra_list = "";

##### Match Tokens
#$::SLASH_CMT = "(?:\\\/\\\/\([^\\n]*\)\\n)"; ### //   efrse fh single line comment

my $toDir = $dir;
my $project = "";
$toDir =~ s/[\\\/]$//gi;

dataLog("START\n");

find(\&make_lists, $toDir);
#print join "\n", @files;
$files_length = $#files+1;
#print "$files_length = $#files and length(@files)\n";
processTrace(@files);

dataLog("END\n");

sub make_lists {
  if($File::Find::name !~ /\/(.svn)\//si and -f $File::Find::name and $File::Find::name =~ /(\.java)$/si){
    push(@files,  $File::Find::name);
  }
}

sub processTrace {
  my @arr = @_;
  my $i = 1;
  foreach my $file (@arr){
      print "$file\n";
      applyTrace("$file", $i);
      $i++;
  }
  return;
}

sub applyTrace {
  my $file = shift;
  my $count = shift;
  my $fileName = "";  

  $fileName = $file;
  $fileName =~ s/^(.*)[\\\/]([^\\\/]+)$/$2/gi;
    
  #print $fileName," poda\n";
  
  dataLog("Processing $file - $count out of $files_length\n");
  
  $/="\0";
  open(FIN,"<$file") || die "can not open \"$file\" file : $!";
  my $data = <FIN>;
  close FIN;

  $data = call_function_process($data, $fileName);


  #### Global Replacement
  $data =~ s/&lpar;/\(/smgi;
  $data =~ s/&rpar;/\)/smgi;
  
  open(FOUT,">${file}_out") || die "can not open \"${file}_out\" file : $!";
  print FOUT $data;
  close FOUT;

  eval{
	&copy("${file}_out", "${file}");
	unlink("${file}_out");
  };
  if($@)
  {
    print("\tCan not copy file name from \"${file}_out\" to \"${file}\" : $@\n");
    exit;
  }
  
  return ;
}

sub call_function_process
{
  my $data = shift;
  my $fileName = shift;
  my $packageName = "";

  my $fileName_wo_extn = $fileName;
  $fileName_wo_extn =~ s/\.java//sgi;

  if($data =~ /\[SRC FLOW ANALYSIS/smig){
     return $data;
  }
  
  if($data =~ /package ([^\;]+)\;/smig){
     $packageName = $1;
  }

  #package dk.tdc.kvikoc.web.actions;
  # public List<FacParamMockClass> getFacParams() {
  # public void setAgreementId(String agreementId) {
  # public List<OperatorInfoVO> getOperatorList() throws WebBaseException {

  ### for Function process
  while($data =~ /\n(\s|\t)*(public|private) ([^\n\(\=]*)\(/smig)
  {
  	### First we need to check semicolns in the line terminator
      	$prefix = $`;
      	$postfix = $';
      	$match = $&;
      	
      	my $functionName = $match;
      	my $functionArgs = "";
      	
      	$functionName =~ s/^.* ([^\s]+)\s*\(/$1/sgi;;

      	my $flag = 0;
      	my $after_match = "";
      	my $after_postfix = "";
      	
      	#print $match,"\n\n";
      	
      	my ($before,$after)=&findpair($postfix);
      	
      	$functionArgs = $before;
      	
      	$functionArgs =~ s/[\t\n]//sgi; 
      	
      	my @functionArgs = split (/\,/, $functionArgs);
      	my $functionComments = "";
      	
      	if($functionArgs =~ /./){
      	    $functionComments = "+\" ARGUMENTS:- \"";
      	    foreach my $entry (@functionArgs){
			   ### Removing first and last spaces
			   $entry =~ s/^\s*//sgi;
			   $entry =~ s/\s*$//sgi;
			   $entry =~ s/([\s\t]*)\[/\[/sgi;
			   $entry =~ s/([\s\t]*)\]/\]/sgi;

			   $entry =~ s/^(final )(.*?)$/$2/sgi;
      	       if($entry =~ /^\s*(.*)\s+([^\s]+)$/sgi){
				  my $temp1 = "$1";
				  my $temp2 = "$2";
				  if($temp2 =~ /[\[|\]]/sgi) { $temp2 = ""; }
      	          $functionComments .= "+\"$temp1=\"+ $temp2 ";
      	       }
      	    }
      	}
      	
      	#print $functionComments,"=functionComments\n\n";
      	#print $before,"=before\n\n";
      	#print $after,"=after\n\n";
      	
      	if($after =~ /^\)(\s|\t|\n|)*\;/){
      	   #print "INSIDE PROTO TYPE\n\n";
      	}elsif($after =~ /^\)(\s|\t|\n|[^\{])*\{/){
      	  $flag = 1;
      	  $after_match = $&;
      	  $after_postfix = $';
      	  
      	  $ra_list = "\n\tSystem.out.println &lpar;\"\[SRC FLOW ANALYSIS - MURU\] $packageName $fileName - $functionName\" $functionComments&rpar;\;\n";
      	  
		  print "]${fileName_wo_extn}[ !~ ]${functionName}[\n";
		  if($fileName_wo_extn =~ /$functionName/sgi or "$fileName_wo_extn" eq "$functionName")
		  { 
		      $ra_list = "";
		  }

	      $after = $after_match."$ra_list".$after_postfix;

      	  
      	}

	##### add symbol of findpair functions
	$postfix = $before.''.$after;
      	$match =~ s/\(/&lpar;/smig;
      	$data = $prefix.$match.$postfix;

  }
  return $data;
}

sub dataLog {
  my $message = shift;
  $message =~ s/([\,\n]+)$/\n/gi;
  $message = localtime(time)."\t$message";
  print "$message";
  open APPEND, ">>trace_log.txt" or die "failed to open trace_log.txt: $!\n";
  print APPEND $message;
  close APPEND;
  return;
}

sub findpair
{
	my $tmpcnt=1;
	my $temp="";
	my $srchstr=shift;
	my $counter=0;
	my $outcondt=1;
	my $extra;
	
	while($counter<length($srchstr) && $outcondt)
	{
		my $char=substr($srchstr,$counter,1);
		if ($char eq '('){$tmpcnt++;}
		if ($char eq ')'){$tmpcnt--;}
		if ($tmpcnt == 0){$outcondt=0; $extra=substr($srchstr,$counter)}
		else {$temp.=$char;}
		$counter++;
	}
	return $temp,$extra;
}
