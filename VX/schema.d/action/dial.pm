package action::dial;
# 'Hunting group'

use strict;
use warnings;
use Exporter;

our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( dial DIAL );

# these are exported by default.
our @EXPORT = qw( dial DIAL );

sub dial {
 my $_ = shift; # Params array reference
 my $descr = shift // '';
 my $inline = shift;

 my @p = @{$_};
# my $ext = $p[0] // '';
 my $ext = $::LABELS{"DIAL.".join(' ', @p)};

 print "[Func ". ::FN() ."] $descr\n";
 if (defined $ext) {
  print " Macro = Switch ; (fn,Var,Limit,FallBack)\n";
  print " P1 = Exten($ext)\n";
  if (defined $::Fields{"ROOT.CallLimit"} && $::Fields{"ROOT.CallLimit"} =~ /^\d+$/) {
   print " P3 = " . $::Fields{"ROOT.CallLimit"} . "\n";
   delete $::Fields{"ROOT.CallLimit"};
  }
 } else {
  print "; Nothing to dial is defined!\n";
  print " Macro = Hang ; Terminate call\n";
 }

 print "\n";

 if ($inline) { # Make object
#  for (keys %::Fields) {
#    delete $::Fields{$_} if (/^DIAL\./);
#  }
  my @d;
  my @params = @p ; # ($p[0]);

  ::CSV(shift @p, \@d); # Dial
  $::Fields{"DIAL.Dial"} = join(' ', @d);

  @d = ();
  ::CSV(shift @p, \@d); # Spec
  if (defined $d[0] && $d[0] !~ /^m/i) {
   $::Fields{"DIAL.Hunt"} = $d[0] if $d[0];
   $::Fields{"DIAL.MOH"} = $d[1] if defined $d[1] && $d[1] !~ /^m(oh)?$/i;
   $::Fields{"DIAL.CID"} = $d[2];
  } else {
   $::Fields{"DIAL.CID"} = $d[1];
  }
  $::Fields{"DIAL.Timeout"} = shift @p;

  @d = split('\|', join(' ', @params)); # Spec

  my $t = ::unquote(::trim($d[1])) // '';
  $t = "= dial $t" if $t && $t !~ /^([A-Za-z_.-]+|=)[\s]/;
  $::Fields{"DIAL.TransferOnBusy"} = ($t ne '') ? $t : undef;

  $t = ::unquote(::trim($d[2])) // '';
  $t = "= dial $t" if $t && $t !~ /^([A-Za-z_.-]+|=)[\s]/;
  $::Fields{"DIAL.TransferOnTimeout"} = ($t ne '') ? $t : undef;

  DIAL(\@params, ' ; inline');
 }

 return undef;
}

sub DIAL { # Extension as hunting group
 my $_ = shift; # Params array reference
 my $descr = shift // '';

 my @p = @{$_};
# my $ext = $p[0] // '';
 return if $::OBJECTS{"DIAL.".join(' ', @p)};

 my $ext = $::LABELS{"DIAL.".join(' ', @p)};

 my $Hunt = $::Fields{'DIAL.Hunt'} // $::Fields{'ROOT.Hunt'} // 'P';
# print "*** $Hunt\n ";
 $Hunt = uc(substr($Hunt,0,1));
 $Hunt = 'P' unless ($Hunt =~ /^[PRS]/);

 my $Timeout = $::Fields{'DIAL.Timeout'} // $::Fields{'ROOT.Timeout'} // '86400';
 $Timeout =~ s/\D//g;

 my $MOH = $::Fields{'DIAL.MOH'} // $::Fields{'ROOT.MOH'} // '';
 my $CID = $::Fields{'DIAL.CID'} // $::Fields{'ROOT.CID'} // '';
 my @Dial = ();
 ::Keys($::Fields{'DIAL.Dial'},\@Dial);

 $_ = uc(substr($CID,0,1));
 $CID = '';
 $CID = '!' if /A/;
 $CID = '>' if /B/;

 print "[Exten $ext]$descr\n";
 print " CallLevel = 4 ; Limit hunting to in-zone calls\n";
 print " MOH = $MOH ; Music class\n" if $MOH ne '' && $MOH !~ /^r(ing)?$/i;

 if (scalar @Dial < 2) {
  if (defined $Dial[0]) {
   if ($Dial[0] =~ /(:\d+)$/p) {
    $Timeout = substr(${^MATCH},1);
    $Dial[0] = ${^PREMATCH}
   }
   print " TransferCall = $CID$Dial[0]\n";
  } else {
   print "; Nothing to dial is defined!"
  }
 } else {
   print " SpawnCalls = :$Hunt$CID:," . join(',',@Dial) . "\n";
 }
 print " Timeout = $Timeout ; Max time in seconds for single call\n" if $Timeout;

 # OnBusy & OnTimeout actions
 my @act = ();
 my @lb = ();
 my $obj = $::OBJECT; # Must be redefined when inline!
 my $lab = $::LABEL;  #
 $::OBJECT = 'DIAL';

 my $TransferOnBusy = $::Fields{'DIAL.TransferOnBusy'};
 my $TransferOnTimeout = $::Fields{'DIAL.TransferOnTimeout'};
 my @k = ();
 my $val;

 if (defined $TransferOnBusy) {
  ::Keys($TransferOnBusy,\@k);
  if ($k[0] eq 'ext') {
   $val = $k[1];
  } else { # Just extend current object with '.B'|'.T'
   $::LABELS{"DIAL.TransferOnBusy"} = "$ext.B"; # Rewrite!
   push(@act, $TransferOnBusy);
   push(@lb, "TransferOnBusy");
   $val = $::LABELS{"DIAL.TransferOnBusy"};
  }
  print " TransferOnBusy = $val\n";
 }
 if (defined $TransferOnTimeout) {
  ::Keys($TransferOnTimeout,\@k);
  if ($k[0] eq 'ext') {
   $val = $k[1];
  } else {
   $::LABELS{"DIAL.TransferOnTimeout"} = "$ext.T"; # Rewrite!
   push(@act, $TransferOnTimeout);
   push(@lb, "TransferOnTimeout");
   $val = $::LABELS{"DIAL.TransferOnTimeout"};
  }
  print " TransferOnTimeout = $val\n";
 }

 print "\n";

 my $i = 0;
 for (@act) {
  $::LABEL = $lb[$i++]; # Still need the label hack :/
  $::oi = -1;
  ::Action($_);
 }
 $::OBJECT = $obj;
 $::LABEL = $lab;

 $::OBJECTS{"DIAL.".join(' ', @p)} = 1;
 return;
}
